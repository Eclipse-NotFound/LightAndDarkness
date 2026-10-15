package {
    import flash.desktop.NativeApplication;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.KeyboardEvent;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.text.TextField;
    import flash.text.TextFieldType;
    import flash.utils.getDefinitionByName;
    import flash.utils.getTimer;
    public class KeybindProbe extends Sprite {
        private static var probe:KeybindProbe;
        private var main:*,world:*,runtime:*;
        private var fixture:KeybindFixtureCarrier;
        private var api:KeybindFixtureAPI;
        private var phase:int=0,tick:int=0,started:int;
        private var cold:Boolean=false;
        private var sharedMode:Boolean=false;
        private var shared:*;
        private var lamp:Object;
        public function KeybindProbe() {}
        public static function init(main:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-keybind-")!=0) return;
            probe=new KeybindProbe();probe.main=main;probe.started=getTimer();
            var mode:String=probe.read(File.applicationDirectory.resolvePath("keybind-mode.txt"));
            probe.cold=mode=="cold";probe.sharedMode=mode=="shared";
            main.stage.addEventListener(Event.ENTER_FRAME,probe.frame,false,-100);
            probe.log("BOOT "+NativeApplication.nativeApplication.applicationID);
        }
        private function read(file:File):String {var stream:FileStream=new FileStream();stream.open(file,FileMode.READ);var value:String=stream.readUTFBytes(stream.bytesAvailable);stream.close();return value;}
        private function write(file:File,value:String):void {var stream:FileStream=new FileStream();stream.open(file,FileMode.WRITE);stream.writeUTFBytes(value);stream.close();}
        private function log(value:String):void {var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("keybind-test.log"),FileMode.APPEND);stream.writeUTFBytes(getTimer()+" "+value+"\n");stream.close();}
        private function check(ok:Boolean,label:String):void {if(!ok) throw new Error(label);log("PASS "+label);}
        private function event(type:String,code:int,ctrl:Boolean=false,alt:Boolean=false,shift:Boolean=false):void {
            var e:KeyboardEvent=new KeyboardEvent(type,true,false,0,code,0,ctrl,alt,shift);
            if(api) api.feed(e);main.dispatchEvent(e);
        }
        private function press(code:int,ctrl:Boolean=false,alt:Boolean=false,shift:Boolean=false):void {event(KeyboardEvent.KEY_DOWN,code,ctrl,alt,shift);event(KeyboardEvent.KEY_UP,code,ctrl,alt,shift);}
        private function stopNativeAssignment(event:KeyboardEvent):void {event.stopImmediatePropagation();}
        private function unitChecks():void {
            var Keys:Class=runtime.keys.constructor as Class;
            var file:File=File.applicationStorageDirectory.resolvePath("unit-keys.json");
            write(file,'{"version":1,"headlamp":76}');
            var keys:*=new Keys(file);
            check(keys.getBinding("headlamp").code==76 && !keys.getBinding("headlamp").alt,"legacy numeric key migrates without modifiers");
            check(keys.getBinding("fixture").code==69 && keys.getBinding("fixture").alt,"missing action keeps default");
            var clone:Object=keys.getBinding("fixture");clone.code=99;
            check(keys.getBinding("fixture").code==69,"binding getters do not leak mutable state");
            keys.setBinding("headlamp",{code:0,ctrl:true,alt:true,shift:true});
            var loaded:*=new Keys(file),binding:Object=loaded.getBinding("headlamp");
            check(binding.code==0 && !binding.ctrl && !binding.alt && !binding.shift,"unbound binding persists normalized");
            var before:String=read(file),rejected:Boolean=false;
            try {keys.setBinding("headlamp",{code:16});} catch(error:*) {rejected=true;}
            check(rejected && read(file)==before,"modifier-only binding rejected without write");
            write(file,'{"version":9,"headlamp":{"code":12}}');before=read(file);keys=new Keys(file);rejected=false;
            try {keys.setBinding("headlamp",{code:75});} catch(future:*) {rejected=true;}
            check(rejected && read(file)==before,"unknown configuration retained");
        }
        private function finish():void {main.stage.removeEventListener(Event.ENTER_FRAME,frame);log("SUITE_PASS");}
        private function hudChecks():void {
            var Hud:Class=main.getChildByName("LightAndDarknessHUD").constructor as Class;
            var hud:*=new Hud();
            hud.show(1100,true,"Alt+E 切换附近灯具",0,"Alt+L");
            hud.show(1100,true,"Alt+E 切换附近灯具",0,"Ctrl+K");
            check(TextField(hud.getChildAt(0)).text.indexOf("Ctrl+K")>=0,"cached HUD refreshes headlamp binding without progress change");
            hud.show(1100,true,"Shift+J 切换附近灯具",0,"Ctrl+K");
            check(TextField(hud.getChildAt(0)).text.indexOf("Shift+J")>=0,"cached HUD refreshes fixture binding without layout change");
        }
        private function flag(owner:*,name:String):String {var value:String="";try {value=String(owner[name]);} catch(error:*) {value=String(error);}return value;}
        private function sharedDiagnostics():void {
            log("DIAG sharedHeld="+shared.isKeyDown("light-and-darkness-hotkeys","fixture")+" localHeld="+runtime.keys.held("fixture")+" progress="+runtime.repairProgress+" nearest="+(runtime.nearestLamp()===lamp)+" hp="+lamp.state.hp+" key="+JSON.stringify(runtime.keys.getBinding("fixture")));
            log("DIAG allStat="+flag(world,"allStat")+" console="+flag(world,"onConsol")+" pause="+flag(world,"onPause")+" setkey="+flag(world.ctr,"setkeyOn")+" guiPause="+flag(world.gui,"guiPause")+" privateDial="+flag(world.gui,"dial")+" publicDialVisible="+world.gui.vis.getChildByName("dial").visible+" focus="+main.stage.focus);
            for each(var name:String in ["mm","pip","sats","stand"]) {
                var child:*=null;try {child=world[name];} catch(error:*) {log("DIAG "+name+" access "+error);}
                log("DIAG "+name+" active="+(child==null?"null":flag(child,"active")));
            }
        }
        private function frame(e:Event):void {
            try {
                var wc:Class=getDefinitionByName("fe.World") as Class;world=wc["w"];
                if(world && world.verror && world.verror.visible) throw new Error("HOST_ERROR "+world.verror.txt.text);
                if(getTimer()-started>160000) throw new Error("TIMEOUT phase="+phase);
                if(phase==0 && world && world.allLandsLoaded && world.textLoaded && world.mm) {world.mm.mainMenuOff();world.newGame(-1,"LP",{propusk:true});phase=1;}
                else if(phase==1 && world.gg && world.loc && world.allStat==1) {
                    var carrier:*=main.getChildByName("LightAndDarknessCarrier");if(!carrier) return;
                    runtime=carrier.ladAPI.runtime;if(runtime.location!==world.loc) return;
                    world.gui.dialText(null);phase=2;tick=0;
                } else if(phase==2 && ++tick>20) {
                    // Isolated gameplay fixture: leave the new-game dialogue before testing gameplay keys.
                    world.gui.dialText(null);world.gui.guiPause=false;world.gui.dialScript.running=false;
                    var original:Boolean=runtime.store.data.headlamp;
                    hudChecks();
                    if(cold) {
                        check(runtime.keys.getBinding("headlamp").code==75 && runtime.keys.getBinding("headlamp").ctrl,"cold process loads custom headlamp binding");
                        check(runtime.keys.getBinding("fixture").code==74 && runtime.keys.getBinding("fixture").shift,"cold process loads custom repair binding");
                        press(76,false,true);check(runtime.store.data.headlamp==original,"cold process ignores old binding");
                        press(75,true);check(runtime.store.data.headlamp!=original,"cold custom binding drives native runtime");finish();return;
                    }
                    if(sharedMode) {
                        var sharedCarrier:*=main.getChildByName("ModSettingsCarrier");
                        if(!sharedCarrier || sharedCarrier.modAPI.keybindVersion!=1) return;
                        shared=sharedCarrier.modAPI;
                        var sharedPage:Object=null;
                        for each(var p:Object in shared.getPages()) if(p.modId=="light-and-darkness-hotkeys") sharedPage=p;
                        if(!sharedPage) return;
                        check(sharedPage.items.length==2,"actual shared host accepts two client binding rows");
                        check(shared.beginKeyCapture("light-and-darkness-hotkeys","headlamp") && shared.isCapturingKey(),"actual host begins capture");
                        event(KeyboardEvent.KEY_DOWN,17,true);check(shared.isCapturingKey(),"modifier alone keeps real capture waiting");
                        event(KeyboardEvent.KEY_DOWN,75,true);event(KeyboardEvent.KEY_DOWN,75,true);
                        check(!shared.isCapturingKey() && runtime.keys.getBinding("headlamp").code==75 && runtime.keys.getBinding("headlamp").ctrl,"actual capture invokes persistent client setter");
                        check(runtime.store.data.headlamp==original,"actual capture and key repeat do not trigger headlamp");
                        event(KeyboardEvent.KEY_UP,75,true);event(KeyboardEvent.KEY_UP,17);
                        press(75,true);check(runtime.store.data.headlamp!=original,"actual new binding triggers after captured release");
                        shared.beginKeyCapture("light-and-darkness-hotkeys","fixture");press(75,true);
                        check(shared.isCapturingKey() && runtime.keys.getBinding("fixture").code==69,"actual host rejects duplicate action binding");
                        press(74,false,false,true);
                        check(!shared.isCapturingKey() && runtime.keys.getBinding("fixture").code==74 && runtime.keys.getBinding("fixture").shift,"actual host accepts distinct fixture chord");
                        shared.beginKeyCapture("light-and-darkness-hotkeys","headlamp");press(27);
                        check(!shared.isCapturingKey() && runtime.keys.getBinding("headlamp").code==75,"actual Escape cancels without changing binding");
                        shared.beginKeyCapture("light-and-darkness-hotkeys","headlamp");press(46);
                        check(runtime.keys.getBinding("headlamp").code==0,"actual Delete clears client binding");
                        original=runtime.store.data.headlamp;press(75,true);check(runtime.store.data.headlamp==original,"cleared actual binding cannot act");
                        sharedPage.items[0].set(sharedPage.items[0].def);press(76,false,true);
                        check(runtime.store.data.headlamp!=original,"actual menu default callback restores original action");
                        shared.beginKeyCapture("light-and-darkness-hotkeys","headlamp");press(75,true);
                        original=runtime.store.data.headlamp;press(75,true,false,true);
                        check(runtime.store.data.headlamp==original,"actual shared matching rejects extra modifier");
                        var hidden:TextField=new TextField();hidden.type=TextFieldType.INPUT;main.addChild(hidden);main.stage.focus=hidden;hidden.visible=false;
                        press(75,true);check(runtime.store.data.headlamp!=original,"actual host and client ignore hidden input focus");
                        main.stage.focus=null;main.removeChild(hidden);
                        lamp=runtime.lamps[3];lamp.state.atmosphere.mode="steady";runtime.hitLamp(lamp,100);
                        world.gg.setPos(lamp.x+30,480);world.gg.fixed=true;world.invent.items["scrap"].kol=10;
                        phase=50;tick=0;return;
                    }
                    unitChecks();
                    check(runtime.keys.label("headlamp")=="Alt+L" && runtime.keys.label("fixture")=="Alt+E","old defaults preserved without service");
                    press(76,true,true);check(runtime.store.data.headlamp==original,"extra modifier does not match default");
                    event(KeyboardEvent.KEY_DOWN,76,false,true);event(KeyboardEvent.KEY_DOWN,76,false,true);
                    check(runtime.store.data.headlamp!=original,"native headlamp repeats toggle only once");event(KeyboardEvent.KEY_UP,76,false,true);
                    runtime.keys.setBinding("headlamp",{code:0});original=runtime.store.data.headlamp;press(76,false,true);
                    check(runtime.store.data.headlamp==original,"unbound native action disabled");
                    runtime.keys.setBinding("headlamp",{code:75,ctrl:true});press(76,false,true);
                    check(runtime.store.data.headlamp==original,"rebind immediately disables previous key");
                    press(75,true);check(runtime.store.data.headlamp!=original,"custom fallback binding acts immediately");
                    original=runtime.store.data.headlamp;press(75,true,false,true);
                    check(runtime.store.data.headlamp==original,"custom fallback requires exact modifiers");
                    world.onPause=true;press(75,true);world.onPause=false;
                    check(runtime.store.data.headlamp==original,"paused game suppresses action");
                    var input:TextField=new TextField();input.type=TextFieldType.INPUT;main.addChild(input);main.stage.focus=input;press(75,true);
                    check(runtime.store.data.headlamp==original,"input focus suppresses action");
                    input.visible=false;press(75,true);
                    check(runtime.store.data.headlamp!=original,"hidden input focus does not block gameplay");original=runtime.store.data.headlamp;
                    main.stage.focus=null;main.removeChild(input);
                    world.onConsol=true;press(75,true);world.onConsol=false;
                    check(runtime.store.data.headlamp==original,"console suppresses action");
                    main.stage.addEventListener(KeyboardEvent.KEY_DOWN,stopNativeAssignment,true,800);
                    world.ctr.setkeyOn=true;press(75,true);world.ctr.setkeyOn=false;
                    main.stage.removeEventListener(KeyboardEvent.KEY_DOWN,stopNativeAssignment,true);
                    check(runtime.store.data.headlamp==original,"native key assignment suppresses action");
                    world.gui.vis.getChildByName("dial").visible=true;press(75,true);world.gui.vis.getChildByName("dial").visible=false;
                    check(runtime.store.data.headlamp==original,"public dialog visibility suppresses action");
                    fixture=new KeybindFixtureCarrier();api=fixture.modAPI;main.addChildAt(fixture,0);phase=3;tick=0;
                } else if(phase==3 && ++tick>3) {
                    check(api.pages["light-and-darkness"]!=null && api.pages["light-and-darkness-hotkeys"]==null && api.rejectedPages==0,"legacy service retains feature page and skips keybind page");
                    api.keybindVersion=1;phase=4;tick=0;
                } else if(phase==4 && ++tick>3) {
                    var page:Object=api.pages["light-and-darkness-hotkeys"];
                    check(page && page.items.length==2 && page.navigation.moduleId=="light-and-darkness" && page.navigation.featureName=="快捷键","late service registers one authoritative key page");
                    check(api.item("headlamp").def.code==76 && api.item("headlamp").def.alt && api.item("fixture").def.code==69,"menu defaults preserve original chords");
                    api.item("headlamp").set({code:75,ctrl:true,alt:false,shift:false});
                    api.item("fixture").set({code:74,ctrl:false,alt:false,shift:true});
                    original=runtime.store.data.headlamp;press(75,true);
                    check(runtime.store.data.headlamp!=original && api.matchingCalls>0,"runtime delegates matching to shared service");
                    original=runtime.store.data.headlamp;api.capture=true;press(75,true);api.capture=false;
                    check(runtime.store.data.headlamp==original,"capture suppresses native shortcut");
                    api.suppressed=true;press(75,true);api.suppressed=false;
                    check(runtime.store.data.headlamp==original,"captured key release quarantine honored");
                    press(75,true);check(runtime.store.data.headlamp!=original,"new press acts after quarantine");
                    lamp=runtime.lamps[3];lamp.state.atmosphere.mode="steady";runtime.hitLamp(lamp,100);
                    world.gg.setPos(lamp.x+30,480);world.gg.fixed=true;world.invent.items["scrap"].kol=10;phase=5;tick=0;
                } else if(phase==5 && ++tick>10) {
                    check(runtime.nearestLamp()===lamp,"repair target reachable");
                    event(KeyboardEvent.KEY_DOWN,74,false,false,true);phase=6;tick=0;
                } else if(phase==6 && ++tick>=18) {
                    check(runtime.repairProgress>0 && runtime.repairProgress<1 && api.heldCalls>0,"remapped repair uses shared held state");
                    event(KeyboardEvent.KEY_DOWN,17,true,false,true);phase=7;tick=0;
                } else if(phase==7 && ++tick>2) {
                    check(runtime.repairProgress==0 && lamp.state.hp==0 && world.invent.items["scrap"].kol==10,"extra modifier cancels repair without charge");
                    event(KeyboardEvent.KEY_UP,17,false,false,true);event(KeyboardEvent.KEY_UP,74,false,false,true);
                    event(KeyboardEvent.KEY_DOWN,74,false,false,true);phase=8;tick=0;
                } else if(phase==8 && ++tick>=70) {
                    event(KeyboardEvent.KEY_UP,74,false,false,true);
                    check(lamp.state.hp==40 && world.invent.items["scrap"].kol==8,"remapped held repair completes once");
                    runtime.hitLamp(lamp,12);event(KeyboardEvent.KEY_DOWN,74,false,false,true);phase=9;tick=0;
                } else if(phase==9 && ++tick>=15) {
                    check(runtime.repairProgress>0,"second remapped repair started");api.capture=true;phase=10;tick=0;
                } else if(phase==10 && ++tick>2) {
                    check(runtime.repairProgress==0 && world.invent.items["scrap"].kol==8,"capture cancels active repair without charge");api.capture=false;
                    event(KeyboardEvent.KEY_UP,74,false,false,true);
                    api.item("headlamp").set({code:0});original=runtime.store.data.headlamp;press(75,true);
                    check(runtime.store.data.headlamp==original,"menu clear disables binding");
                    api.item("headlamp").set(api.item("headlamp").def);press(76,false,true);
                    check(runtime.store.data.headlamp!=original,"menu restore default works immediately");
                    api.item("headlamp").set({code:75,ctrl:true});api.item("fixture").set({code:74,shift:true});
                    main.removeChild(fixture);api=null;phase=11;tick=0;
                } else if(phase==11 && ++tick>3) {
                    original=runtime.store.data.headlamp;press(75,true);
                    check(runtime.store.data.headlamp!=original,"service disappearance preserves persisted fallback");
                    event(KeyboardEvent.KEY_DOWN,74,false,false,true);main.stage.dispatchEvent(new Event(Event.DEACTIVATE));world.onPause=false;
                    check(runtime.repairProgress==0 && !runtime.keys.held("fixture"),"focus loss clears local held repair");
                    var saved:Object=JSON.parse(read(File.applicationStorageDirectory.resolvePath("LightAndDarkness.keys.json")));
                    check(saved.headlamp.code==75 && saved.fixture.code==74,"menu changes immediately persisted outside save slots");
                    finish();
                } else if(phase==50 && ++tick>10) {
                    world.gui.dialText(null);event(KeyboardEvent.KEY_DOWN,74,false,false,true);phase=51;tick=0;
                } else if(phase==51 && ++tick>=18) {
                    sharedDiagnostics();
                    check(runtime.repairProgress>0 && shared.isKeyDown("light-and-darkness-hotkeys","fixture"),"actual shared held-state drives repair");
                    shared.beginKeyCapture("light-and-darkness-hotkeys","headlamp");phase=52;tick=0;
                } else if(phase==52 && ++tick>2) {
                    check(runtime.repairProgress==0 && world.invent.items["scrap"].kol==10,"actual capture cancels held repair");
                    press(27);event(KeyboardEvent.KEY_UP,74,false,false,true);
                    event(KeyboardEvent.KEY_DOWN,74,false,false,true);phase=53;tick=0;
                } else if(phase==53 && ++tick>=70) {
                    event(KeyboardEvent.KEY_UP,74,false,false,true);
                    check(lamp.state.hp==40 && world.invent.items["scrap"].kol==8,"actual host remapped repair completes with one charge");
                    main.stage.dispatchEvent(new Event(Event.DEACTIVATE));world.onPause=false;
                    check(!shared.isKeyDown("light-and-darkness-hotkeys","fixture") && !runtime.keys.held("fixture"),"actual host focus loss clears held state");
                    check(read(File.applicationStorageDirectory.resolvePath("LightAndDarkness.keys.json")).indexOf('"code":75')>=0,"actual host changes persisted to client file");finish();
                }
            } catch(error:*) {main.stage.removeEventListener(Event.ENTER_FRAME,frame);log("FAIL "+error+" "+error.getStackTrace());}
        }
    }
}
