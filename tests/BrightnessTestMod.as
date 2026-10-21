package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.Event;
    import flash.filesystem.*;
    import flash.geom.*;
    import flash.net.*;
    import flash.system.*;
    import flash.utils.*;

    /** Isolated probe: production classes are obtained from the loaded candidate, never linked here. */
    public class BrightnessTestMod extends Sprite {
        private static var self:BrightnessTestMod;
        private var main:*,w:*,r:*,cfg:Object,rv:Object,cs:Object;
        private var baseline:Loader=new Loader(),oldDomain:ApplicationDomain;
        private var baselineStarted:Boolean=false;
        private var started:int,phase:int=0,frames:int=0,index:int=0,checks:int=0,lastBeat:int=0,waitSince:int=0;
        private var rvWaitSince:int=0,rvWaitFrames:int=0;
        private var targets:Array=[],samples:Array=[],assertions:Array=[],current:Object;
        private var oldEnv:*,oldField:*,oldAtmos:*,oldHead:Boolean,oldRV:Boolean,oldFog:Boolean;
        private var stableData:BitmapData,stableSignature:String,stableCamera:String,stableSignatureOK:Boolean;
        private var settledFrames:int=0,observedFrames:int=0;
        public function BrightnessTestMod() {}
        public static function init(root:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-brightness-")!=0)return;
            self=new BrightnessTestMod();self.main=root;self.started=getTimer();
            self.cfg=JSON.parse(self.read("brightness-config.json",false));
            self.targets=self.cfg.mode=="large"?["random_mane","random_plant"]:(self.cfg.mode=="smoke" || self.cfg.mode=="cold")?[]:["surf","random_mane","random_sewer","random_encl","src"];
            self.baseline.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {self.oldDomain=self.baseline.contentLoaderInfo.applicationDomain;});
            root.stage.addEventListener(Event.ENTER_FRAME,self.step,false,-170);
        }
        private function read(name:String,storage:Boolean=true):String {
            var fs:FileStream=new FileStream();fs.open((storage?File.applicationStorageDirectory:File.applicationDirectory).resolvePath(name),FileMode.READ);
            var value:String=fs.readUTFBytes(fs.bytesAvailable);fs.close();return value;
        }
        private function write(name:String,text:String,append:Boolean=false):void {
            var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath(name),append?FileMode.APPEND:FileMode.WRITE);fs.writeUTFBytes(text);fs.close();
        }
        private function check(ok:Boolean,label:String,detail:*=null):void {
            assertions.push({pass:ok,label:label,detail:detail});write("checks.log",(ok?"PASS ":"FAIL ")+label+" "+JSON.stringify(detail)+"\n",true);
            if(!ok)throw new Error("ASSERT "+label);checks++;
        }
        private function png(name:String,b:BitmapData):void {
            var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);fs.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));fs.close();
        }
        private function photo(name:String):void {var b:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);b.draw(main.stage);png(name,b);b.dispose();}
        private function samePixels(first:BitmapData,second:BitmapData):Boolean {
            if(first.width!=second.width || first.height!=second.height)return false;
            var difference:Object=first.compare(second),same:Boolean=difference===0;
            if(difference is BitmapData)BitmapData(difference).dispose();return same;
        }
        private function finish(error:String=""):void {
            main.stage.removeEventListener(Event.ENTER_FRAME,step);
            if(stableData){stableData.dispose();stableData=null;}
            var carrier:*=main.getChildByName("LightAndDarknessCarrier");
            write("brightness.json",JSON.stringify({version:carrier?carrier.ladAPI.version:"",baselineVersion:cfg.baselineVersion,roomsLoad:w?w.roomsLoad:0,
                checks:checks,error:error,mode:cfg.mode,loader:SharedObject.getLocal("ModLoader","/").data,samples:samples,assertions:assertions,
                applicationID:NativeApplication.nativeApplication.applicationID,
                boundary:"Native Tile fixtures and same paused native scene, candidate versus frozen 0.6.0 classes. Software captures, no FPS claim or player storage."},null,2));
            write("brightness.done",error?"FAIL "+error:"PASS");NativeApplication.nativeApplication.exit(error?1:0);
        }
        private function room(land:String="test",fon:String="fonDefault"):Object {
            var T:Class=getDefinitionByName("fe.loc.Tile") as Class;
            var map:Object={spaceX:24,spaceY:25,space:[],backwall:"tBackWall",backform:0,transpFon:false,sky:false,base:false,lightOn:0,
                color:"",colorfon:"",homeStable:false,backobjs:[],spawnPoints:[],acts:[],firstObj:null,id:"background-test",land:{act:{id:land,tip:"test",fon:fon}}};
            for(var x:int=0;x<24;x++){map.space[x]=[];for(var y:int=0;y<25;y++){var t:*=new T(x,y);t.opac=0;t.phis=0;map.space[x][y]=t;}}
            return map;
        }
        private function renderer(back:BitmapData):Object {
            var visual:Sprite=new Sprite(),a:Sprite=new Sprite(),b:Sprite=new Sprite(),c:Sprite=new Sprite();
            a.addChild(new Bitmap(back));visual.addChild(a);visual.addChild(b);visual.addChild(c);
            return {visual:visual,visBack:a,visBack2:b,visFront:c,sceneLarge:false};
        }
        private function exercise():void {
            var E:Class=r.environment.constructor as Class,F:Class=r.field.constructor as Class;
            var env:*=new E(),field:*=new F(),view:Rectangle=new Rectangle(0,0,960,996),map:Object;
            var base:Number,light:Number,dark:Number,x:int,y:int,bitmap:BitmapData=null,owned:Array=[];
            try {
                map=room();check(getQualifiedClassName(map.space[0][0])=="fe.loc::Tile","fixtures use the native typed Tile path");
                var expected:Array=[{land:"rbl",safe:true,value:.82},{land:"random_sewer",value:.48},{land:"begin",value:.48},
                    {land:"random_encl",value:.72},{land:"test",value:.68},{land:"random_mane",value:.62}];
                for each(var p:Object in expected){map=room(p.land);map.base=Boolean(p.safe);env.bind(map,null,"profile");check(Math.abs(env.profile(300,300).ambient-p.value)<.0001,"selected closed-region ambient "+p.land,{actual:env.profile(300,300).ambient,expected:p.value});}
                map=room("random_mane","fonRuins");map.transpFon=true;env.bind(map,null,"daylight");
                check(Math.abs(env.profile(300,300).ambient-.62)<.0001,"daylight city keeps sheltered ruins at the regional floor");
                map=room("random_sewer");map.lightOn=-1;env.bind(map,null,"outage");check(Math.abs(env.profile(300,300).ambient-.24)<.0001,"explicit power outage retains its dark floor");

                map=room();map.sky=true;env.bind(map,null,"flight");field.render(map,view,[],.14,null,1,env);
                check(field.sample(300,300)<.70,"flight flag alone does not create daylight");
                map.sky=false;map.backwall="sky";map.land.act.fon="fonWay";env.bind(map,null,"sky");field.render(map,view,[],.14,null,1,env);
                check(field.sample(300,300)>.65,"native sky geometry still supplies daylight without flight flag");

                map=room("random_mane","fonRuins");map.backwall="tWindows";map.transpFon=true;
                bitmap=new BitmapData(960,1000,true,0xff505050);bitmap.fillRect(new Rectangle(240,240,160,160),0);
                var g:Object=renderer(bitmap);env.bind(map,g,"native-raster-opening");field.render(map,view,[],.14,null,1,env);
                light=field.sample(300,300);dark=field.sample(820,800);
                check(light>dark+.15 && light>.60,"transparent rendered window wall supplies local light",{opening:light,covered:dark});
                field.render(map,view,[],.14,null,1,env);field.render(map,view,[],.14,null,1,env);
                var unchanged:String=env.signature(),stable:BitmapData=field.data.clone(),same:Boolean=true;
                try {
                    for(var repeat:int=0;repeat<10;repeat++){
                        same=same && unchanged==env.signature();field.render(map,view,[],.14,null,1,env);
                        same=same && unchanged==env.signature();
                    }
                    check(same,"unchanged ordinary raster retains a stable environment signature");
                    check(samePixels(stable,field.data),"repeated static render preserves identical field pixels");
                } finally {stable.dispose();}
                var sealedBack:BitmapData=new BitmapData(960,1000,true,0xff505050);owned.push(sealedBack);
                Bitmap(g.visBack.getChildAt(0)).bitmapData=sealedBack;field.render(map,view,[],.14,null,1,env);
                check(field.sample(300,300)<light-.15,"ordinary room replacement bitmap invalidates its backdrop transmission");
                Bitmap(g.visBack.getChildAt(0)).bitmapData=bitmap;
                map=room("random_sewer","fonDefault");map.transpFon=true;env.bind(map,g,"underground-raster");field.render(map,view,[],.14,null,1,env);
                check(field.sample(300,300)<.50,"transparent raster without exterior context cannot invent underground sky");
                bitmap.dispose();bitmap=null;

                map=room("random_mane","fonRuins");map.backwall="tWindows";map.transpFon=true;
                var surfaces:Array=[],chunk:Object,gLarge:Object={sceneLarge:true,sceneResident:0,sceneEvictions:0,sceneChunkSide:320,
                    sceneSurfaces:function():Array{return surfaces;}};
                env.bind(map,gLarge,"before-raster");field.render(map,view,[],.14,null,1,env);dark=field.sample(460,180);
                check(dark<.65,"unrasterized CS chunk is unknown rather than transparent sky");
                var front:BitmapData=new BitmapData(320,320,true,0),back:BitmapData=new BitmapData(320,320,true,0xff505050),rear:BitmapData=new BitmapData(320,320,true,0);
                owned.push(front,back,rear);back.fillRect(new Rectangle(80,80,120,120),0);
                chunk={x:320,y:0,gutter:0,side:320,cx:1,cy:0,nativeBuffers:[front,back,rear]};surfaces.push(chunk);gLarge.sceneResident=1;
                field.render(map,view,[],.14,null,1,env);light=field.sample(460,180);
                check(light>dark+.15,"CS first resident raster invalidates previously empty backdrop cache",{empty:dark,resident:light});
                var replacement:BitmapData=new BitmapData(320,320,true,0xff505050);owned.push(replacement);chunk.nativeBuffers[1]=replacement;
                field.render(map,view,[],.14,null,1,env);
                check(field.sample(460,180)<dark+.01,"CS replacement raster refreshes aperture transmission");

                map=room("random_mane","fonRuins");
                var styles:Array=[{bounds:new Rectangle(0,0,400,1000),style:{backwall:"sky",backform:0,color:"",homeStable:false,transpFon:true}},
                    {bounds:new Rectangle(400,0,560,1000),style:{backwall:"tBackWall",backform:0,color:"",homeStable:false,transpFon:false}}];
                var slices:Object={sceneRegionSlices:function(...args):Array{return styles;}};
                for(y=0;y<25;y++)map.space[10][y].opac=map.space[10][y].phis=1;
                env.bind(map,slices,"mixed-regions");field.render(map,view,[],.14,null,1,env);dark=field.sample(500,300);base=env.profile(500,300).ambient;
                check(env.regions.length==2 && field.sample(300,300)>.65 && Math.abs(dark-base)<.01,"room slices retain independent indoor and outdoor air fields",{outdoor:field.sample(300,300),indoor:dark,base:base});
                check(field.sample(402,300)>base+.08,"opaque wall receives sky on its exposed face",{surface:field.sample(402,300),base:base});
                check(field.sample(460,300)<=base+.01,"surface reception does not transmit through a thin wall",{behind:field.sample(460,300),base:base});
                map.space[10][7].opac=map.space[10][7].phis=0;field.render(map,view,[],.14,null,1,env);light=field.sample(500,300);
                check(light>dark+.03 && Math.abs(light-.67)<.01,"opening native Tile door invalidates cached sky occlusion",{open:light,closed:dark});
                map.space[10][7].opac=map.space[10][7].phis=1;field.render(map,view,[],.14,null,1,env);
                check(Math.abs(field.sample(500,300)-dark)<.01,"closing door restores the original air darkness");
                for(x=0;x<10;x++)for(y=0;y<25;y++)map.space[x][y].back="tConcrete";
                field.render(map,view,[],.14,null,1,env);dark=field.sample(300,300);
                check(dark<.65,"new background masonry blocks geometric daylight");
                for(x=0;x<10;x++)for(y=0;y<25;y++)map.space[x][y].back="";
                field.render(map,view,[],.14,null,1,env);check(field.sample(300,300)>dark+.12,"background destruction invalidates daylight cache");
                png("fixture-surface-field",field.data);

                map=room("random_mane","fonRuins");
                bitmap=new BitmapData(960,1000,true,0);bitmap.fillRect(new Rectangle(0,400,960,600),0xff505050);
                var floorFront:BitmapData=new BitmapData(960,1000,true,0);owned.push(floorFront);
                floorFront.fillRect(new Rectangle(0,430,960,50),0xff505050);
                var floorGrafon:Object=renderer(bitmap);floorGrafon.visFront.addChild(new Bitmap(floorFront));
                var floorStyles:Array=[{bounds:new Rectangle(0,0,960,400),style:{backwall:"sky",backform:0,color:"",homeStable:false,transpFon:true}},
                    {bounds:new Rectangle(0,400,960,600),style:{backwall:"tBackWall",backform:0,color:"",homeStable:false,transpFon:false}}];
                floorGrafon.sceneRegionSlices=function(...args):Array{return floorStyles;};
                for(x=0;x<24;x++){
                    map.space[x][10].phis=1;map.space[x][10].setZForm(3);
                    map.space[x][11].opac=map.space[x][11].phis=1;
                }
                check(map.space[7][10].phY1==430 && map.space[7][10].opac==0 && map.space[7][10].phis==1,"native zForm 3 fixture retains actual partial-floor geometry and opacity");
                env.bind(map,floorGrafon,"native-fractured-floor");field.render(map,view,[],.14,null,1,env);base=env.profile(300,434).ambient;
                check(field.sample(300,434)>base+.08,"native fractured floor receives sky at its actual visible top",{surface:field.sample(300,434),base:base});
                check(field.sample(300,434)>field.sample(300,402)+.01,"fractured floor reception follows its physical top rather than the tile top",{surface:field.sample(300,434),airAbove:field.sample(300,402)});
                check(field.sample(300,500)<=base+.01,"opaque floor below a partial native tile still prevents through-light");
                for each(var cached:Boolean in [true,false]){
                    field.sceneCache=cached;field.render(map,view,[],.14,null,1,env);dark=field.sample(300,414);
                    for(x=0;x<24;x++)map.space[x][10].setZForm(1);
                    floorFront.fillRect(floorFront.rect,0);floorFront.fillRect(new Rectangle(0,410,960,70),0xff505050);
                    field.render(map,view,[],.14,null,1,env);light=field.sample(300,414);
                    check(light>dark+.025,"native zForm edit refreshes same-bitmap surface light with sceneCache="+cached,{before:dark,after:light,opacity:map.space[7][10].opac});
                    for(x=0;x<24;x++)map.space[x][10].setZForm(3);
                    floorFront.fillRect(floorFront.rect,0);floorFront.fillRect(new Rectangle(0,430,960,50),0xff505050);
                    field.render(map,view,[],.14,null,1,env);
                    check(Math.abs(field.sample(300,414)-dark)<.005,"restoring native zForm restores the surface field with sceneCache="+cached);
                }
                field.sceneCache=true;
                bitmap.dispose();bitmap=null;

                var Back:Class=getDefinitionByName("fe.graph.BackObj") as Class;
                for each(var id:String in ["enil","hole1","chole1","fwindow"]){
                    map=room("random_encl","fonEnclave");map.transpFon=true;
                    map.backobjs=[new Back(w.loc,id,240,240)];env.bind(map,null,"native-aperture-"+id);
                    check(env.openings.length>0,"native aperture mask is collected: "+id,{sources:env.openings.length});
                    field.render(map,view,env.lights(view),.14,null,1,env);
                    var source:Object=env.openings[0];light=-1;
                    for each(var aperture:Object in env.openings){var value:Number=field.sample(aperture.x,aperture.y);if(value>light){light=value;source=aperture;}}
                    base=env.profile(source.x,source.y).ambient;
                    check(light>base+.04,"native aperture contributes illumination: "+id,{value:light,base:base});
                    if(id=="enil"){
                        map.backobjs[0].alpha=0;field.render(map,view,env.lights(view),.14,null,1,env);
                        check(field.sample(source.x,source.y)<=base+.01,"hiding a native aperture invalidates its cached environment light");
                        map.backobjs[0].alpha=1;field.render(map,view,env.lights(view),.14,null,1,env);
                        check(field.sample(source.x,source.y)>base+.04,"restoring native aperture alpha restores environmental light");
                    }
                    map.land.act.id="random_sewer";map.land.act.fon="fonDefault";map.transpFon=false;env.bind(map,null,"underground-"+id);
                    check(env.openings.length==0,"closed underground rejects decorative aperture: "+id);
                }
                map=room("src","fonWay");map.backobjs=[new Back(w.loc,"swindow",240,240)];env.bind(map,null,"native-src-window");
                check(env.openings.length>0 && env.lights(view).length>0,"src fonWay admits its original swindow as an exterior source");
                field.render(map,view,env.lights(view),.14,null,1,env);light=-1;
                for each(aperture in env.openings)light=Math.max(light,field.sample(aperture.x,aperture.y));
                check(light>.60,"native src swindow illuminates the shared field",light);
                map=room("random_mane","fonRuins");map.backobjs=[new Back(w.loc,"stwindow",240,240)];env.bind(map,null,"internal-window");
                check(env.openings.length==0,"internal observation glass does not become an outdoor source");

                map=room();env.bind(map,null,"multiplier");field.render(map,view,[],.14,null,1,env);base=field.sample(300,300);
                field.render(map,view,[],.14*1.25,null,1,env);light=field.sample(300,300);
                check(Math.abs(light/base-1.25)<.025,"environment multiplier preserves selective ambient scaling",{normal:base,scaled:light});
                field.render(map,view,[],.14,null,1,env);check(Math.abs(field.sample(300,300)-base)<.005,"restoring multiplier restores exact base field");
                var lamp:Object={id:"toggle",x:300,y:300,radius:300,color:0xffffff,power:1,angle:0,cone:Math.PI*2};
                field.render(map,view,[lamp],.14,null,1,env);light=field.sample(300,300);
                field.render(map,view,[],.14,null,1,env);check(light>base+.3 && Math.abs(field.sample(300,300)-base)<.005,"switching off a dynamic lamp leaves no retained illumination");
            } finally {if(bitmap)bitmap.dispose();for each(var buffer:BitmapData in owned)buffer.dispose();field.clear();env.clear();}
        }
        private function preferences():void { BrightnessChecks.run(main,w,r,check,png); }
        private function settingItem(modId:String,key:String):Object {
            var c:*=main.getChildByName("ModSettingsCarrier");if(!c)return null;
            for each(var page:Object in c.modAPI.getPages())if(page.modId==modId)for each(var item:Object in page.items)if(item.key==key)return item;
            return null;
        }
        private function dismiss():void {w.gui.dialText(null);w.gui.guiPause=false;w.gui.dialScript.running=false;}
        private function beginSample():void {
            dismiss();w.onPause=true;oldHead=r.store.data.headlamp;r.store.data.headlamp=false;r.render();
            oldRV=rv?Boolean(rv.get()):false;oldFog=w.grafon.visLight.visible;
            var OE:Class=oldDomain.getDefinition("lad.LadEnvironment") as Class,OF:Class=oldDomain.getDefinition("lad.LadLightField") as Class,OA:Class=oldDomain.getDefinition("lad.LadAtmosphere") as Class;
            check(OE!==r.environment.constructor && OF!==r.field.constructor,"baseline and candidate lighting classes remain separate "+w.game.curLandId);
            check(oldDomain.getDefinition("fe.loc.Tile")===getDefinitionByName("fe.loc.Tile"),"baseline inherits the same native Tile identity "+w.game.curLandId);
            oldEnv=new OE();oldField=new OF();oldAtmos=new OA();oldAtmos.config=r.atmosphere.config;oldAtmos.settings=r.atmosphere.settings;
            var Store:Class=oldDomain.getDefinition("lad.LadStore") as Class,roomKey:String=String(Store["roomKey"](w.loc));
            oldEnv.bind(w.loc,w.grafon,roomKey);
            current={prefix:"sample-"+(samples.length+1),land:w.game.curLandId,room:w.loc.id,regions:r.environment.regions.length,
                backwall:w.loc.backwall,backform:w.loc.backform,transpFon:w.loc.transpFon,fon:w.loc.land.act.fon,mode:cfg.mode,
                rvEnabled:oldRV,headlamp:false,worldPaused:true,roomKey:roomKey,environment:r.environment.profile(w.gg.X,w.gg.Y).ambient};samples.push(current);
            var nativeWindows:int=0,nativeVisibleWindows:int=0,environmentWindows:int=0;
            for each(var nativeBack:* in w.loc.backobjs)if(String(nativeBack.id)=="swindow"){
                nativeWindows++;if(nativeBack.alpha>0 && nativeBack.erase)nativeVisibleWindows++;
            }
            for each(var opening:Object in r.environment.openings)if(String(opening.id).indexOf("window:swindow:")==0)environmentWindows++;
            current.swindow={nativeObjects:nativeWindows,visibleMasks:nativeVisibleWindows,environmentSources:environmentWindows};
            if(current.land=="src" && nativeVisibleWindows>0)check(environmentWindows>0,"actual src exterior windows provide environment sources",current.swindow);
            var sceneCarrier:*=main.getChildByName("ContinuousSceneCarrier"),nativeState:Object=null;
            if(sceneCarrier && sceneCarrier.nativeAPI)nativeState=sceneCarrier.nativeAPI.state(w.land);
            current.scene={nativeEnabled:cs?Boolean(cs.get()):false,sceneLarge:Boolean(w.grafon.sceneLarge),spaceX:w.loc.spaceX,spaceY:w.loc.spaceY,
                nativeRegions:nativeState?nativeState.regions.length:0,stateUsesCurrentLocation:nativeState?nativeState.loc===w.loc:false,
                viewReady:w.grafon.sceneLarge?w.grafon.sceneViewReady():true};
            if(cfg.mode=="large" && samples.length>1){
                check(current.scene.nativeEnabled && current.scene.sceneLarge && current.scene.stateUsesCurrentLocation && current.scene.viewReady,
                    "actual CS native renderer and resident scene are active "+current.land,current.scene);
                check(current.regions>1 && nativeState.regions.length>1 && w.loc.spaceX==nativeState.width && w.loc.spaceY==nativeState.height,
                    "actual CS joined scene exposes multiple environment regions "+current.land,{lighting:current.regions,nativeRegions:current.scene.nativeRegions,width:w.loc.spaceX,height:w.loc.spaceY});
            } else check(!current.scene.sceneLarge,"ordinary scene uses native room rendering "+current.land,current.scene);
            pair("actual");
            if(rv)rv.set(false);phase=3;frames=0;
        }
        private function camera():Array {var m:Matrix=w.grafon.visual.transform.concatenatedMatrix;return [m.a,m.b,m.c,m.d,m.tx,m.ty];}
        private function summary(field:*):Object {
            var air:Array=[],solid:Array=[];
            for(var x:int=0;x<w.loc.spaceX;x++)for(var y:int=0;y<w.loc.spaceY;y++)if(field.bounds.contains(x*40+20,y*40+20)){
                var value:Number=field.sample(x*40+20,y*40+20);(w.loc.space[x][y].opac>=.99?solid:air).push(value);
            }
            air.sort(Array.NUMERIC);solid.sort(Array.NUMERIC);
            return {airPoints:air.length,airMedian:air.length?air[int(air.length/2)]:null,solidPoints:solid.length,solidMedian:solid.length?solid[int(solid.length/2)]:null};
        }
        private function pair(label:String):void {
            r.render();var before:Array=camera();photo(current.prefix+"-candidate-"+label);
            var topLeft:Point=w.grafon.visual.globalToLocal(new Point(0,0)),bottomRight:Point=w.grafon.visual.globalToLocal(new Point(main.stage.stageWidth,main.stage.stageHeight));
            var view:Rectangle=new Rectangle(topLeft.x,topLeft.y,bottomRight.x-topLeft.x,bottomRight.y-topLeft.y),sources:Array=r.lights(view),ownOpenings:int=r.environment.lights(view).length;
            sources=sources.slice(ownOpenings);sources=oldEnv.lights(view).concat(sources);
            oldField.render(w.loc,view,sources,r.ambient,r.atmosphere.settings.darkZones?oldAtmos.zones(w.loc,current.roomKey,oldEnv):null,r.atmosphere.settings.darkness,oldEnv);
            var holder:DisplayObjectContainer=r.field.bitmap.parent,pos:int=holder.getChildIndex(r.field.bitmap),visible:Boolean=r.field.bitmap.visible;
            try {r.field.bitmap.visible=false;holder.addChildAt(oldField.bitmap,pos+1);photo(current.prefix+"-baseline060-"+label);}
            finally {if(oldField.bitmap.parent)oldField.bitmap.parent.removeChild(oldField.bitmap);r.field.bitmap.visible=visible;}
            var originalVisible:Boolean=r.field.bitmap.visible;
            try {r.field.bitmap.visible=false;photo(current.prefix+"-native-"+label);}
            finally {r.field.bitmap.visible=originalVisible;}
            check(JSON.stringify(before)==JSON.stringify(camera()),"same paused camera for candidate and 0.6.0 "+current.land+" "+label);
            current[label]={camera:before,candidate:summary(r.field),baseline:summary(oldField)};
            if(label=="isolated"){png(current.prefix+"-candidate-field",r.field.data);png(current.prefix+"-baseline060-field",oldField.data);}
        }
        private function controlled():void {
            w.grafon.visLight.visible=false;pair("isolated");
            var ambient:Number=r.ambient;r.ambient=ambient*1.25;r.render();photo(current.prefix+"-ambient125");r.ambient=ambient;r.render();
            write("progress.json",JSON.stringify(samples,null,2));
            oldField.clear();oldEnv.clear();oldField=oldEnv=oldAtmos=null;
            if(rv)rv.set(oldRV);w.grafon.visLight.visible=oldFog;r.store.data.headlamp=oldHead;phase=4;frames=0;
        }
        private function stableFrame():void {
            if(++frames<8)return;
            r.render();
            var signature:String=r.environment.signature(),position:String=JSON.stringify(camera());
            if(!stableData || signature!=stableSignature || position!=stableCamera || !samePixels(stableData,r.field.data)){
                if(stableData)stableData.dispose();stableData=r.field.data.clone();
                stableSignature=signature;stableCamera=position;observedFrames=0;settledFrames=frames;
                write("settling.log",getTimer()+" "+current.land+" frame="+frames+" resident="+w.grafon.sceneResident+" evictions="+w.grafon.sceneEvictions+"\n",true);
                check(frames<180,"native scene settles within 180 frames "+current.land,{frame:frames,resident:w.grafon.sceneResident});
                return;
            }
            if(++observedFrames<8)return;
            current.stability={settleFrames:settledFrames,observedFrames:observedFrames,signatureStable:true,pixelsStable:true,cameraStable:true};
            check(signature==r.environment.signature(),"paused native scene retains its environment signature across eight frames "+current.land);
            check(samePixels(stableData,r.field.data) && position==JSON.stringify(camera()),"paused candidate scene preserves camera and field pixels across eight frames "+current.land,current.stability);
            stableData.dispose();stableData=null;controlled();
        }
        private function travel():void {
            if(index>=targets.length){finish();return;}dismiss();w.pers.healAll();w.onPause=false;
            if(targets[index]=="random_encl")w.game.triggers["encounter_post"]=1;
            w.game.beginMission(targets[index]);phase=2;frames=0;waitSince=getTimer();
        }
        private function step(e:Event):void {
            try {
                w=getDefinitionByName("fe.World")["w"];
                if(getTimer()-lastBeat>10000){lastBeat=getTimer();write("heartbeat.log",lastBeat+" phase="+phase+"\n",true);}
                if(w && w.verror && w.verror.visible)throw new Error(w.verror.txt.text);
                if(getTimer()-started>540000)throw new Error("timeout phase="+phase+" target="+targets[index]);
                if(!baselineStarted){
                    // The launcher loads this probe before LightAndDarkness alphabetically.
                    // Do not let the reference define same-name classes before the candidate finishes loading.
                    var candidate:*=main.getChildByName("LightAndDarknessCarrier");
                    if(!candidate || !candidate.ladAPI || !candidate.ladAPI.runtime)return;
                    check(candidate.ladAPI.version==cfg.expectedVersion,"candidate initializes before loading baseline definitions",candidate.ladAPI.version);
                    baselineStarted=true;
                    baseline.load(new URLRequest(File.applicationDirectory.resolvePath("baseline.swf").url),new LoaderContext(false,new ApplicationDomain(main.loaderInfo.applicationDomain)));
                }
                    if(phase==5){
                        if(++frames<4)return;
                        BrightnessChecks.ui(main,check,png);main.getChildByName("ModSettingsCarrier").modAPI.togglePage("light-and-darkness-regions");
                        w.pip.onoff(-1);dismiss();w.onPause=true;beginSample();return;
                    }
                if(phase==2 && getTimer()-waitSince>150000)throw new Error("native travel or raster timeout target="+targets[index]);
                if(phase==0 && oldDomain && w && w.allLandsLoaded && w.textLoaded && w.mm){
                    if(cfg.mixed){
                        if(waitSince==0)waitSince=getTimer();
                        if(getTimer()-waitSince>45000)throw new Error("CS startup or settings interface did not become ready");
                        var sceneCarrier:*=main.getChildByName("ContinuousSceneCarrier");cs=settingItem("continuousscene","nativeEnabled");
                        if(!sceneCarrier || !sceneCarrier.sceneAPI.ready || !cs)return;
                        check(sceneCarrier.sceneAPI.version!=null,"comparison uses installed ContinuousScene interface",sceneCarrier.sceneAPI.version);
                        cs.set(cfg.mode=="large");check(cs.get()===(cfg.mode=="large"),"CS native mode is explicitly applied and read back before map generation",cs.get());
                    }
                    var B:Class=oldDomain.getDefinition("LightAndDarknessMod") as Class;check(B["VERSION"]==cfg.baselineVersion,"frozen comparison class reports baseline 0.6.0",B["VERSION"]);
                    w.mm.mainMenuOff();w.newGame(-1,"LP",{propusk:true});phase=1;
                } else if(phase>0 && w.gg && w.loc && w.loc.active && w.allStat==1 && w.t_exit==0){
                    var c:*=main.getChildByName("LightAndDarknessCarrier");if(!c)return;r=c.ladAPI.runtime;
                    if(c.ladAPI.version!=cfg.expectedVersion)throw new Error("unexpected candidate version "+c.ladAPI.version);
                    if(r.location!==w.loc)return;
                    if(phase==3){stableFrame();return;}
                    if(phase==4){if(++frames>=8){if(samples.length>1)index++;travel();}return;}
                    if(phase==2 && (w.game.curLandId!=targets[index] || w.land.act.id!=targets[index]))return;
                    if(phase==2 && cfg.mode=="large" && (!w.grafon.sceneLarge || !w.grafon.sceneViewReady())){frames=0;return;}
                    if(++frames<12)return;
                    if(samples.length==0){
                        rv=settingItem("realisticvision","enabled");
                        if(cfg.mixed && !rv){
                            if(rvWaitSince==0){rvWaitSince=getTimer();write("heartbeat.log","Waiting for RV settings registration before fixture pause\n",true);}
                            rvWaitFrames++;
                            if(getTimer()-rvWaitSince>45000)check(false,"RV setting interface available for isolated lighting comparison",{waitMs:getTimer()-rvWaitSince,waitFrames:rvWaitFrames});
                            return;
                        }
                        if(cfg.mixed)check(rv!=null,"RV setting interface available for isolated lighting comparison",{waitMs:rvWaitSince?getTimer()-rvWaitSince:0,waitFrames:rvWaitFrames});
                        dismiss();w.onPause=true;exercise();preferences();
                        w.pip.noAct=false;w.pip.onoff(5);
                        check(main.getChildByName("ModSettingsCarrier").modAPI.togglePage("light-and-darkness-regions"),"regional native settings page opens");
                        phase=5;frames=0;return;
                    }
                    beginSample();
                }
            }catch(error:*){finish(String(error)+" "+error.getStackTrace());}
        }
    }
}
