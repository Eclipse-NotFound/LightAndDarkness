package {
    import flash.desktop.NativeApplication;
    import flash.display.Sprite;
    import flash.display.BitmapData;
    import flash.display.PNGEncoderOptions;
    import flash.display.MovieClip;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.events.Event;
    import flash.events.KeyboardEvent;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.utils.getDefinitionByName;
    import flash.utils.getTimer;
    import flash.utils.ByteArray;
    public class LightAndDarknessTest extends Sprite {
        private static var test:LightAndDarknessTest;
        private var main:*;
        private var world:*;
        private var runtime:*;
        private var phase:int=0;
        private var start:int;
        private var tick:int=0;
        private var lampKey:String;
        private var roomKey:String;
        private var lamp:Object;
        private var savedState:String;
        private var previousLocation:*;
        private var baselineUnits:int;
        private var baselineLights:int;
        private var performance:Array=[];
        private var mixed:Boolean=false;
        private var cold:Boolean=false;
        private var scene:*;
        private var largeUnits:int;
        private var markX:int;
        private var markY:int;
        private var markColor:uint;
        private const KEY:String="lightanddarkness.state.v1";
        public function LightAndDarknessTest() {}
        public static function init(main:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-test-")!=0) return;
            test=new LightAndDarknessTest();test.main=main;test.start=getTimer();
            var stream:FileStream=new FileStream();stream.open(File.applicationDirectory.resolvePath("test-mode.txt"),FileMode.READ);
            var mode:String=stream.readUTFBytes(stream.bytesAvailable);test.mixed=mode=="mixed";test.cold=mode=="cold";stream.close();
            main.stage.addEventListener(Event.ENTER_FRAME,test.frame,false,-100);
            test.log("BOOT "+NativeApplication.nativeApplication.applicationID);
        }
        private function log(value:String):void {
            var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("test.log"),FileMode.APPEND);
            stream.writeUTFBytes(getTimer()+" "+value+"\n");stream.close();
        }
        private function snapshot(name:String):void {
            var bitmap:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);
            bitmap.draw(main.stage);
            var bytes:ByteArray=bitmap.encode(bitmap.rect,new PNGEncoderOptions());
            var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);
            stream.writeBytes(bytes);stream.close();bitmap.dispose();log("SCREEN "+name);
        }
        private function check(pass:Boolean,label:String):void {LightCoreChecks.check(pass,label,log);}
        private function key(type:String,code:int):void {
            // Bubble from a child so the production stage capture listener handles it.
            main.dispatchEvent(new KeyboardEvent(type,true,false,0,code,0,false,true,false));
        }
        private function findLamp():Object {
            for each(var value:Object in runtime.lamps) if(value.key==lampKey) return value;
            throw new Error("saved lamp missing: "+lampKey);
        }
        private function nativeBullet(damage:Number):void {
            var BulletClass:Class=getDefinitionByName("fe.weapon.Bullet") as Class;
            var bullet:*=new BulletClass(world.gg,lamp.x-8,lamp.y,null,false);
            bullet.damage=damage;bullet.tipDamage=0;bullet.dx=8;bullet.dy=0;bullet.partEmit=false;
            bullet.run();
            log("BULLET hp="+lamp.state.hp+" hit="+runtime.hits+" xy="+bullet.X+","+bullet.Y+" off="+bullet.off+" parr="+bullet.parr+" proxy="+[lamp.proxy.disabled,lamp.proxy.trigDis,lamp.proxy.sost,lamp.proxy.fraction,lamp.proxy.loc===world.loc,lamp.proxy.X1,lamp.proxy.Y1,lamp.proxy.X2,lamp.proxy.Y2]);
        }
        private function finish():void {
            main.stage.removeEventListener(Event.ENTER_FRAME,frame);log("SUITE_PASS");
            // The supervisor stops this exact test process; the host intercepts native exit with a save prompt.
        }
        private function fixtureAtlas():void {
            var board:Sprite=new Sprite();board.graphics.beginFill(0x30333a);board.graphics.drawRect(0,0,700,850);board.graphics.endFill();
            var ids:Array=["light1","stlight1","light2","light3","stlight3","light4","stlight4","light5","light6","light7"];
            for(var i:int=0;i<ids.length;i++) {
                var label:TextField=new TextField();label.defaultTextFormat=new TextFormat("_sans",16,0xffffff);label.text=ids[i];label.x=5;label.y=10+i*84;board.addChild(label);
                for(var f:int=1;f<=3;f++) {
                    var clip:MovieClip=world.grafon.getObj("back_"+ids[i]+"_t",1);
                    if(f>clip.totalFrames) continue;
                    clip.gotoAndStop(f);clip.x=140+(f-1)*180;clip.y=12+i*84;clip.scaleX=clip.scaleY=1.6;board.addChild(clip);
                }
            }
            var data:BitmapData=new BitmapData(700,850,false,0);data.draw(board);
            var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("fixture-frames.png"),FileMode.WRITE);
            stream.writeBytes(data.encode(data.rect,new PNGEncoderOptions()));stream.close();data.dispose();
        }
        private function largeSurface():Object {
            for each(var surface:Object in world.grafon.sceneSurfaces()) if(surface.cx==0 && surface.cy==0) return surface;
            throw new Error("missing verification chunk");
        }
        private function frame(event:Event):void {
            try {
                var wc:Class=getDefinitionByName("fe.World") as Class;world=wc["w"];
                if(world && world.verror && world.verror.visible) throw new Error("HOST_ERROR "+world.verror.txt.text);
                if(getTimer()-start>175000) throw new Error("TIMEOUT phase="+phase);
                if(phase==0 && world && world.landData && world.allLandsLoaded && world.textLoaded && world.mm) {
                    world.mm.mainMenuOff();world.newGame(cold?7:-1,"LP",{propusk:true});phase=1;log(cold?"COLD_LOAD_SLOT_7":"NEW_GAME");
                } else if(phase==1 && world.gg && world.loc && world.loc.active && world.allStat==1) {
                    var carrier:*=main.getChildByName("LightAndDarknessCarrier");
                    if(!carrier) return;runtime=carrier.ladAPI.runtime;
                    if(runtime.location!==world.loc) return;
                    if(cold) {
                        lampKey="light1:200.00:400.00:1:1:0";lamp=findLamp();
                        check(lamp.state.hp==0 && !runtime.store.data.headlamp,"cold process restores broken fixture and headlamp");
                        check(world.invent.items["scrap"].kol==10,"cold process restores original inventory");
                        previousLocation=world.loc;world.comLoad=8;phase=100;return;
                    }
                    log("ATTACHED lamps="+runtime.lamps.length+" room="+world.loc.id+" large="+world.grafon.sceneLarge);
                    for each(var foundFixture:Object in runtime.lamps) log("LAMP "+foundFixture.key+" at="+foundFixture.x+","+foundFixture.y+" bounds="+foundFixture.bounds);
                    phase=2;tick=0;
                } else if(phase==2 && ++tick>45) {
                    check(runtime.enabled && runtime.steps>30 && runtime.lamps.length==9,"native room fixture conversion");
                    LightCoreChecks.run(runtime,log);
                    fixtureAtlas();
                    world.gui.dialText(null);
                    lamp=runtime.lamps[3];lampKey=lamp.key;baselineUnits=world.loc.units.length;
                    check(lamp.type=="light1","fixture selection");
                    check(lamp.bo.vis==null && lamp.bo.light==null && lamp.proxy.vis==null,"baked glow removed without native AI visual");
                    world.gg.setPos(lamp.x+30,480);world.gg.fixed=true;world.invent.items["scrap"].kol=10;
                    runtime.store.data.headlamp=false;runtime.store.flush();
                    phase=3;tick=0;
                } else if(phase==3 && ++tick>12) {
                    runtime.render();snapshot("lit");
                    baselineLights=runtime.lights().length;
                    check(runtime.nearestLamp()===lamp,"reachable fixture");
                    log("SHOT tile="+world.loc.getAbsTile(lamp.x,lamp.y).phis+" at="+lamp.x+","+lamp.y);
                    nativeBullet(12);check(lamp.state.hp==28,"native projectile collision damage");
                    nativeBullet(100);check(lamp.state.hp==0 && lamp.proxy.disabled,"native projectile break");
                    runtime.render();snapshot("broken");
                    check(runtime.lights().length==baselineLights-1,"broken light removed from illumination");
                    world.pip.noAct=false;world.saveGame(7);
                    check(world.getSave(7).game!=null,"native save completed");
                    savedState=world.getSave(7).game.triggers[KEY];
                    check(savedState is String,"native slot includes immutable JSON state");
                    key(KeyboardEvent.KEY_DOWN,69);phase=4;tick=0;
                } else if(phase==4 && ++tick>=18) {
                    check(runtime.repairProgress>0 && runtime.repairProgress<1,"held repair progresses");
                    key(KeyboardEvent.KEY_UP,69);
                    check(lamp.state.hp==0 && world.invent.items["scrap"].kol==10 && runtime.repairProgress==0,"release cancels without charge");
                    world.invent.items["scrap"].kol=1;
                    check(!runtime.beginRepair(lamp),"repair rejects insufficient materials");
                    world.invent.items["scrap"].kol=10;
                    key(KeyboardEvent.KEY_DOWN,69);phase=5;tick=0;
                } else if(phase==5 && ++tick>=70) {
                    key(KeyboardEvent.KEY_UP,69);
                    check(lamp.state.hp==40 && world.invent.items["scrap"].kol==8 && runtime.repairs==1,"two-second repair charges exactly once");
                    check(world.getSave(7).game.triggers[KEY]===savedState,"later repair cannot mutate older slot");
                    snapshot("repaired");
                    key(KeyboardEvent.KEY_DOWN,69);key(KeyboardEvent.KEY_UP,69);
                    check(!lamp.state.on,"fixture switch");
                    world.saveGame(8);
                    previousLocation=world.loc;world.comLoad=7;phase=6;tick=0;
                } else if(phase==6 && world.loc && world.loc!==previousLocation && runtime.location===world.loc && world.allStat==1) {
                    lamp=findLamp();check(lamp.state.hp==0 && !runtime.store.data.headlamp,"native load restores broken lamp and headlamp switch");
                    check(world.invent.items["scrap"].kol==10,"native load restores inventory separately");
                    previousLocation=world.loc;world.comLoad=8;phase=7;tick=0;
                } else if(phase==7 && world.loc && world.loc!==previousLocation && runtime.location===world.loc && world.allStat==1) {
                    lamp=findLamp();check(lamp.state.hp==40 && !lamp.state.on,"second slot restores repaired but switched-off lamp");
                    check(world.loc.units.length==baselineUnits,"load leaves one proxy per fixture");
                    world.grafon.visBack2.getChildAt(0).bitmapData.setPixel32(12,12,0xff123456);
                    runtime.setEnabled(false);
                    check(world.grafon.visBack2.getChildAt(0).bitmapData.getPixel32(12,12)==0xff123456,"native raster edits survive ordinary-room restoration");
                    check(world.loc.units.length==baselineUnits-9 && lamp.bo.vis!=null && lamp.bo.light!=null,"disable restores native fixture and removes proxies");
                    runtime.setEnabled(true);phase=8;tick=0;
                } else if(phase==8 && runtime.location===world.loc && ++tick>=20) {
                    lamp=findLamp();check(world.loc.units.length==baselineUnits && !lamp.state.on,"reenable preserves state without duplicates");
                    check(world.grafon.visBack2.getChildAt(0).bitmapData.getPixel32(12,12)==0xff123456,"native raster edits survive ordinary-room conversion");
                    check(world.gg.childObjs["LightAndDarknessTick"]!=null,"native player update hook rebound");
                    var expected:Number=runtime.lastBaseVisibility*(0.18+0.82*runtime.lastExposure);
                    check(Math.abs(world.gg.visibility-expected)<=1,"illumination changes native visibility before AI step");
                    var head:Boolean=runtime.store.data.headlamp;
                    key(KeyboardEvent.KEY_DOWN,76);key(KeyboardEvent.KEY_DOWN,76);key(KeyboardEvent.KEY_UP,76);
                    check(runtime.store.data.headlamp!=head,"headlamp key repeat debounced");
                    phase=9;tick=0;
                } else if(phase==9) {
                    performance.push(runtime.field.elapsedMs);
                    if(++tick>=90) {
                        performance.sort(Array.NUMERIC);log("PERF live room render n=90 p50="+performance[45]+" p95="+performance[85]+" max="+performance[89]);
                        check(runtime.enabled && runtime.steps>200,"sustained native gameplay");
                        var BulletClass:Class=getDefinitionByName("fe.weapon.Bullet") as Class;
                        var explosive:*=new BulletClass(world.gg,lamp.x,lamp.y+30,null,false);
                        explosive.iExpl(100,0,90);phase=10;tick=0;
                    }
                } else if(phase==10 && ++tick>=20) {
                    check(lamp.state.hp==0,"native explosion damages fixture");
                    if(!mixed) {finish();return;}
                    var settings:*=main.getChildByName("ModSettingsCarrier");
                    check(settings && settings.modAPI,"shared settings carrier available");
                    var found:Boolean=false;
                    for each(var page:Object in settings.modAPI.getPages()) if(page.modId=="light-and-darkness") found=true;
                    check(found,"light settings registered alongside other mods");
                    scene=main.getChildByName("ContinuousSceneCarrier");
                    check(scene && scene.sceneAPI.ready,"continuous scene registered");
                    world.pers.healAll();world.pip.noAct=false;world.game.triggers["noreturn"]=0;
                    scene.sceneAPI.travel();phase=11;tick=0;
                } else if(phase==11 && world.land && world.land.act.id=="continuous_scene" && world.loc && world.allStat==1 && ++tick>25) {
                    check(runtime.location===world.loc,"large scene attachment succeeded");
                    check(world.grafon.sceneLarge && runtime.enabled && runtime.lamps.length>0,"large scene dynamic lighting active");
                    log("LARGE dims="+world.loc.spaceX+"x"+world.loc.spaceY+" lamps="+runtime.lamps.length+" chunks="+world.grafon.sceneSurfaces().length);
                    var oldPixels:BitmapData=largeSurface().nativeBuffers[0].clone();
                    world.grafon.gwall(2,2);
                    var marked:BitmapData=largeSurface().nativeBuffers[0];
                    var changed:Boolean=false;
                    for(var py:int=120;py<160 && !changed;py++) for(var px:int=120;px<160;px++) {
                        if(oldPixels.getPixel32(px,py)!=marked.getPixel32(px,py)) {markX=px;markY=py;markColor=marked.getPixel32(px,py);changed=true;break;}
                    }
                    oldPixels.dispose();check(changed,"native large-scene paint mark created");
                    largeUnits=world.loc.units.length;runtime.setEnabled(false);runtime.setEnabled(true);phase=12;tick=0;
                } else if(phase==12 && runtime.location===world.loc && ++tick>25) {
                    check(runtime.enabled && world.loc.units.length==largeUnits,"large scene toggle has no proxy leak");
                    check(largeSurface().nativeBuffers[0].getPixel32(markX,markY)==markColor,"large-scene native paint history survives lighting conversion");
                    check(world.grafon.scenePreload,"large-scene preload preference restored");
                    world.gg.setPos(Math.min(world.loc.limX-150,2400),world.gg.Y);world.gg.fixed=true;phase=13;tick=0;
                } else if(phase==13 && ++tick>40) {
                    check(runtime.field.bounds.contains(world.gg.X,world.gg.Y-world.gg.scY/2),"illumination follows large-scene camera");
                    snapshot("large-mixed");log("PERF large mixed last-render-ms="+runtime.field.elapsedMs);
                    finish();
                } else if(phase==100 && world.loc && world.loc!==previousLocation && runtime.location===world.loc && world.allStat==1) {
                    lamp=findLamp();
                    check(lamp.state.hp==40 && !lamp.state.on,"cold process restores repaired switched-off fixture");
                    check(world.invent.items["scrap"].kol==8,"cold process restores repair material cost");
                    finish();
                }
            } catch(error:*) {main.stage.removeEventListener(Event.ENTER_FRAME,frame);log("FAIL "+error+" "+error.getStackTrace());}
        }
    }
}
