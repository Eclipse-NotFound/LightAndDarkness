package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.Event;
    import flash.filesystem.*;
    import flash.geom.*;
    import flash.net.*;
    import flash.system.*;
    import flash.utils.*;

    /** Exact released reference bytes, independent domains; no screenshot in timed runs. */
    public class LightingPerfProbeMod extends Sprite {
        public function LightingPerfProbeMod() {}
        private static var self:LightingPerfProbeMod;
        private var main:*,w:*,r:*,reference:Loader=new Loader(),domain:ApplicationDomain;
        private var cfg:Object,phase:int=0,age:int=0,scene:int=0,started:int,last:int,scriptStart:int;
        private var rows:Array=[],checks:int=0,frameCase:int=0,row:Object,x0:Number,y0:Number;
        private var wrapped:*,wrappedOriginal:*,simulationMs:int=0,simulationCalls:int=0;
        private var diagnostic:int=0;
        private var anchor:Point;
        public static function init(root:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-perf-")!=0)return;
            self=new LightingPerfProbeMod();self.main=root;self.started=getTimer();
            var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("perf.json"),FileMode.READ);self.cfg=JSON.parse(f.readUTFBytes(f.bytesAvailable));f.close();
            self.reference.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {self.domain=self.reference.contentLoaderInfo.applicationDomain;});
            self.reference.load(new URLRequest(File.applicationDirectory.resolvePath("reference.swf").url),new LoaderContext(false,new ApplicationDomain(root.loaderInfo.applicationDomain)));
            root.stage.addEventListener(Event.ENTER_FRAME,self.tick,false,-1000);
            root.stage.addEventListener(Event.ENTER_FRAME,function(e:Event):void {self.scriptStart=getTimer();},false,10000);
        }
        private function save(name:String,value:*):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);f.writeUTFBytes(JSON.stringify(value,null,2));f.close();}
        private function finish(error:String=""):void {
            main.stage.removeEventListener(Event.ENTER_FRAME,tick);
            save("perf-result.json",{ok:!error,error:error,checks:checks,config:cfg,rows:rows,version:r?main.getChildByName("LightAndDarknessCarrier").ladAPI.version:null,loader:SharedObject.getLocal("ModLoader","/").data,frameRate:main.stage.frameRate});
            NativeApplication.nativeApplication.exit(error?1:0);
        }
        private function check(ok:Boolean,label:String):void {if(!ok)throw new Error(label);++checks;}
        private function dismiss():void {w.gui.dialText(null);w.gui.guiPause=false;w.gui.dialScript.running=false;w.ctr.clearAll();w.pip.noAct=false;if(w.pip.active)w.pip.onoff(-1);w.onPause=false;}
        private function view():Rectangle {var a:Point=w.grafon.visual.globalToLocal(new Point()),b:Point=w.grafon.visual.globalToLocal(new Point(main.stage.stageWidth,main.stage.stageHeight));return new Rectangle(a.x,a.y,b.x-a.x,b.y-a.y);}
        private function compare():void {
            w.onPause=true;r.enabled=false;
            var RF:Class=domain.getDefinition("lad.LadLightField") as Class,RE:Class=domain.getDefinition("lad.LadEnvironment") as Class,CF:Class=r.field.constructor as Class;
            var old:*=new RF(),fresh:*=new CF(),env:*=new RE();env.bind(w.loc,w.grafon,"perf");
            var base:Rectangle=view(),sample:Object={scene:scene,land:w.land.act.id,width:w.loc.spaceX,height:w.loc.spaceY,regions:r.environment.regions.length,results:[]};rows.push(sample);anchor=base.topLeft;
            var tx:int=Math.max(0,Math.min(w.loc.spaceX-1,int((base.x+300)/40))),ty:int=Math.max(0,Math.min(w.loc.spaceY-1,int((base.y+200)/40)));
            var tile:*=w.loc.space[tx][ty],opacity:Number=tile.opac,back:String=tile.back,power:Number=w.loc.lightOn;
            try {
                if(cfg.mode=="pixels") {
                    for(var i:int=0;i<96;++i) {
                        var position:int=int(i/4)*4;
                        var v:Rectangle=new Rectangle(base.x+(position<48?position:96-position)*12,base.y+(int(i/4)%6)*12,base.width,base.height);
                        if(i==12)tile.opac=opacity>0?0:1;if(i==20)tile.opac=opacity;
                        if(i==28)tile.back=back==""?"bwall":"";if(i==36)tile.back=back;
                        if(i==44)w.loc.lightOn=-1;if(i==52)w.loc.lightOn=power;
                        if(i>=60 && i<68){v.width*=1.3;v.height*=1.3;}
                        if(i>=76 && i<84){v.x+=1500;v.y+=500;}
                        var lights:Array=inputs(v,i,true),ambient:Number=i>=88?0.10:r.ambient,darkness:Number=i>=92?0.5:1;
                        old.render(w.loc,v,lights,ambient,r.darkZones,darkness,env);
                        fresh.render(w.loc,v,lights,ambient,r.darkZones,darkness,r.environment);
                        var diff:*=fresh.data.compare(old.data),equal:Boolean=diff===0;
                        if(!equal) {
                            var changed:int=0,maxDifference:int=0,examples:Array=[];
                            for(var px:int=0;px<fresh.data.width;++px)for(var py:int=0;py<fresh.data.height;++py) {
                                var pixelBefore:uint=old.data.getPixel(px,py),pixelAfter:uint=fresh.data.getPixel(px,py);
                                if(pixelBefore==pixelAfter)continue;++changed;
                                var delta:int=Math.max(Math.abs((pixelBefore>>16&255)-(pixelAfter>>16&255)),Math.abs((pixelBefore>>8&255)-(pixelAfter>>8&255)),Math.abs((pixelBefore&255)-(pixelAfter&255)));
                                maxDifference=Math.max(maxDifference,delta);if(examples.length<24)examples.push([px,py,pixelBefore.toString(16),pixelAfter.toString(16),delta]);
                            }
                            save("pixel-mismatch.json",{scene:scene,frame:i,changed:changed,maxDifference:maxDifference,examples:examples,bounds:fresh.bounds,lights:lights});
                        }
                        if(diff is BitmapData)diff.dispose();
                        check(equal,"pixel mismatch scene="+scene+" frame="+i);
                        check(old.sample(v.x+200,v.y+200)==fresh.sample(v.x+200,v.y+200),"gameplay sample mismatch "+i);
                    }
                    sample.pixelFrames=96;
                    if("sceneLightBuilds" in fresh){sample.sceneBuilds=fresh.sceneLightBuilds;check(fresh.sceneLightBuilds>0,"steady-light cache was not exercised");}
                } else {
                    for each(var kind:String in ["idle","pan","aim"]) {
                        var snapshots:Array=[];
                        for(i=0;i<100;++i){v=base.clone();if(kind=="pan")v.x+=i*8;snapshots.push({view:v,lights:inputs(v,kind=="idle"?0:i,kind!="idle")});}
                        // ABBA in one world, precomputed identical inputs, no captures or log writes.
                        for(var round:int=0;round<4;++round) {
                            var optimized:Boolean=round==1 || round==2,field:*=optimized?fresh:old;
                            field.clear();var before:int=field.rebuilds,begin:int=getTimer();
                            for each(var s:Object in snapshots)field.render(w.loc,s.view,s.lights,r.ambient,r.darkZones,1,optimized?r.environment:env);
                            sample.results.push({kind:kind,candidate:optimized,ms:getTimer()-begin,calls:snapshots.length,rebuilds:field.rebuilds-before});
                        }
                    }
                }
            } finally {tile.opac=opacity;tile.back=back;w.loc.lightOn=power;old.clear();fresh.clear();env.clear();r.enabled=true;w.onPause=false;}
            save("progress.json",rows);
        }
        private function inputs(v:Rectangle,i:int,moving:Boolean):Array {
            // Trail shape is a separately authorized visual change, tested by its
            // own suite; compare the unchanged lamp/environment raster here.
            var lights:Array=[];for each(var input:Object in r.lights(v))if(!input.trail)lights.push(input);
            if(cfg.mode=="pixels") {
                // Force a visible steady prefix in both small and large maps.
                // Exercise cached power/colour/radius changes and prefix removal.
                var a:Object={id:"prefix-a",x:anchor.x+440,y:anchor.y+300,radius:i>=52 && i<60?210:230,color:i>=68 && i<76?0xaaddff:0xffdda0,power:i>=24 && i<32?0.3:0.7,angle:0,cone:Math.PI*2,staticScene:!(i>=32 && i<40)};
                var b:Object={id:"prefix-b",x:anchor.x+600,y:anchor.y+320,radius:180,color:0xcceeff,power:0.5,angle:0,cone:Math.PI*2,staticScene:true};
                if(i>=60 && i<68)lights.unshift(b,a);else lights.unshift(a,b);
            }
            lights.push({id:"perf-fixed",x:v.x+500-(moving?i*4:0),y:v.y+280,radius:320,color:0xffdda0,power:0.6,angle:0,cone:Math.PI*2});
            lights.push({id:"perf-moving",x:v.x+400+i*4,y:v.y+260,radius:440,color:0xfff0d6,power:i%17==0?0:1,angle:i*Math.PI/90,cone:Math.PI*0.58});
            return lights;
        }
        private function startFrames():void {
            var on:Boolean=frameCase==0 || frameCase==3;
            var variant:String=cfg.variant=="suite"?["fixtures","bitmap","proxy"][diagnostic]:cfg.variant;
            if(w.gg.childObjs["LightAndDarknessTick"]===wrapped)w.gg.childObjs["LightAndDarknessTick"]=wrappedOriginal;
            r.setEnabled(variant=="module"?on:true);r.field.bitmap.visible=on || variant!="bitmap";
            if(variant=="fixtures")for each(var lamp:Object in r.lamps)lamp.holder.cacheAsBitmap=!on;
            if(variant=="proxy")for each(lamp in r.lamps)lamp.proxy.invis=!on;
            if(variant=="staticlights")r.field.sceneLightsCache=!on;
            age=0;last=getTimer();simulationMs=0;simulationCalls=0;
            row={scene:scene,on:on,frames:[],field:[],logic:[],path:{x:x0,y:y0},empty:0,
                lamps:r.lamps.length,units:w.loc.units.length,variant:variant,simulation:[],simulationCalls:[],
                stage:{width:main.stage.stageWidth,height:main.stage.stageHeight},view:view(),cameraScale:w.cam.scaleV};phase=5;
            instrumentSimulation();
        }
        private function instrumentSimulation():void {
            // A test-only delegating wrapper times the real gameplay hook, without
            // adding an extra lighting update or patching production methods.
            if(!r.enabled)return;
            var original:*=w.gg.childObjs["LightAndDarknessTick"];
            if(!original || original===wrapped)return;
            var owner:LightingPerfProbeMod=this;
            wrappedOriginal=original;
            wrapped={vis:null,step:function():void {
                var begin:int=getTimer();original.step();
                owner.simulationMs+=getTimer()-begin;owner.simulationCalls++;
            },addVisual:function():void {original.addVisual();},remVisual:function():void {original.remVisual();},err:function():String {return original.err();}};
            w.gg.childObjs["LightAndDarknessTick"]=wrapped;
        }
        private function tick(e:Event):void {
            try {
                w=getDefinitionByName("fe.World")["w"];
                if(w && w.verror && w.verror.visible)throw new Error(w.verror.txt.text);
                if(getTimer()-started>400000)throw new Error("timeout phase "+phase);
                if(w && w.gg){w.godMode=true;w.gg.invulner=true;}
                if(phase==0 && domain && w && w.allLandsLoaded && w.textLoaded && w.mm) {w.mm.mainMenuOff();w.newGame(-1,"LP",{propusk:true});phase=1;}
                else if(phase==1 && w.gg && w.loc && w.loc.active && w.allStat==1 && w.t_exit==0) {
                    var c:*=main.getChildByName("LightAndDarknessCarrier");if(!c)return;r=c.ladAPI.runtime;if(r.location!==w.loc)return;
                    dismiss();if(++age<25)return;
                    if(cfg.mode=="frames") {x0=Math.max(200,Math.min(w.loc.limX-1400,w.gg.X));y0=w.gg.Y;frameCase=0;startFrames();}
                    else {compare();nextScene();}
                } else if(phase==2 && w.gg && w.land && w.land.act.id=="random_mane" && w.allStat==1 && w.t_exit==0 && r.location===w.loc) {age=0;phase=1;check(w.grafon.sceneLarge,"large scene unavailable");}
                else if(phase==5) {
                    dismiss();w.gg.disabled=false;w.gg.ggControl=true;var now:int=getTimer();
                    if(age==40){
                        row.measuredAt=new Date().time;
                        row.lamps=r.lamps.length;row.units=w.loc.units.length;
                        row.stepStart=r.steps;if("renders" in r)row.renderStart=r.renders;
                        if("sceneLightBuilds" in r.field)row.sceneBuildStart=r.field.sceneLightBuilds;
                        if(row.variant=="staticlights")check(r.field.sceneLightsCache==!row.on,"static composite treatment not applied");
                        if(row.variant=="fixtures" || row.variant=="proxy") {
                            check(r.lamps.length>0,"single-variable probe has no fixtures");
                            for each(var lamp:Object in r.lamps)check(row.variant=="fixtures"?lamp.holder.cacheAsBitmap==!row.on:lamp.proxy.invis==!row.on,"probe treatment not applied");
                        }
                    }
                    if(age>=40) {row.frames.push(now-last);row.logic.push(now-scriptStart);row.field.push(r.enabled?r.field.elapsedMs:0);row.simulation.push(simulationMs);row.simulationCalls.push(simulationCalls);if(w.grafon.sceneLarge && !w.grafon.sceneViewReady())++row.empty;}
                    simulationMs=0;simulationCalls=0;instrumentSimulation();
                    last=now;var distance:Number=Math.max(0,age-40)*8;
                    w.gg.setLocPos(x0+(age<20?1200:Math.min(1200,distance)),y0);w.gg.dx=8;w.gg.dy=0;
                    if(++age>=40+cfg.samples) {
                        row.finishedAt=new Date().time;
                        row.steps=r.steps-row.stepStart;if("renders" in r)row.renders=r.renders-row.renderStart;
                        if("sceneLightBuilds" in r.field)row.sceneBuilds=r.field.sceneLightBuilds-row.sceneBuildStart;
                        rows.push(row);save("progress.json",rows);
                        var active:Boolean=row.variant!="module" || row.on;
                        check(!active || (r.enabled && r.location===w.loc && row.steps>=cfg.samples-5),"lighting simulation stalled case="+frameCase+" steps="+row.steps+" sost="+w.gg.sost+" pause="+w.onPause+" state="+w.allStat);
                        var measured:int=0;for each(var calls:int in row.simulationCalls)measured+=calls;
                        check(!active || measured>=cfg.samples-5,"simulation timing hook missed updates: "+measured);
                        if(++frameCase<4)startFrames();else nextScene();
                    }
                }
            }catch(error:*){finish(String(error)+" "+error.getStackTrace());}
        }
        private function nextScene():void {
            if(cfg.variant=="suite") {
                if(++diagnostic<3){phase=1;age=0;return;}
                finish();return;
            }
            if(scene++>0 || cfg.roomOnly){finish();return;}
            dismiss();r.setEnabled(true);w.pers.healAll();
            getDefinitionByName("fe.loc.Land")["rconnectSeedSource"]=function():uint{return 20261020;};
            w.game.beginMission("random_mane");phase=2;age=0;
        }
    }
}
