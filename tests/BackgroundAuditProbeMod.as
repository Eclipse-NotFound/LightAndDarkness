package {
    import flash.desktop.NativeApplication;
    import flash.display.BitmapData;
    import flash.display.DisplayObject;
    import flash.display.DisplayObjectContainer;
    import flash.display.Sprite;
    import flash.display.PNGEncoderOptions;
    import flash.events.Event;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.net.SharedObject;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;
    import flash.utils.getTimer;

    /** Investigation only. Exact installed LAD bytes; all interventions live in a private AIR process. */
    public class BackgroundAuditProbeMod extends Sprite {
        public function BackgroundAuditProbeMod() {}
        private static var self:BackgroundAuditProbeMod;
        private var main:*,w:*,r:*,rv:Object;
        private var phase:int=0,frames:int=0,index:int=0,started:int;
        private var targets:Array=["surf","random_mane","mtn","stable_pi","random_plant","random_sewer","random_canter","random_encl","minst","random_mbase","begin"];
        private var samples:Array=[],current:Object,large:Boolean=false;
        public static function init(root:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-background-")!=0)return;
            self=new BackgroundAuditProbeMod();self.main=root;self.started=getTimer();
            self.large=File.applicationDirectory.resolvePath("large-mode.txt").exists;
            if(self.large)self.targets=["random_mane","random_plant"];
            root.stage.addEventListener(Event.ENTER_FRAME,self.step,false,-170);
        }
        private function write(name:String,text:String):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);f.writeUTFBytes(text);f.close();}
        private function png(name:String,b:BitmapData):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);f.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));f.close();}
        private function picture(name:String):void {var b:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);b.draw(main.stage);png(current.prefix+"-"+name,b);b.dispose();}
        private function dismiss():void {w.gui.dialText(null);w.gui.guiPause=false;w.gui.dialScript.running=false;}
        private function finish(error:String=""):void {
            main.stage.removeEventListener(Event.ENTER_FRAME,step);
            write("audit.json",JSON.stringify({error:error,version:main.getChildByName("LightAndDarknessCarrier").ladAPI.version,
                applicationID:NativeApplication.nativeApplication.applicationID,roomsLoad:w?w.roomsLoad:null,
                loader:SharedObject.getLocal("ModLoader","/").data,large:large,samples:samples},null,2));
            write("audit.done",error?"FAIL "+error:"PASS");NativeApplication.nativeApplication.exit(error?1:0);
        }
        private function findRV():Object {
            var c:*=main.getChildByName("ModSettingsCarrier");if(!c)return null;
            for each(var page:Object in c.modAPI.getPages()) if(page.modId=="realisticvision")
                for each(var item:Object in page.items)if(item.key=="enabled")return item;
            return null;
        }
        private function layer(o:DisplayObject):Object {
            var ct:*=o.transform.colorTransform,m:Matrix=o.transform.concatenatedMatrix;
            return {name:o.name,type:getQualifiedClassName(o),visible:o.visible,alpha:o.alpha,blend:o.blendMode,
                matrix:[m.a,m.b,m.c,m.d,m.tx,m.ty],color:[ct.redMultiplier,ct.greenMultiplier,ct.blueMultiplier,ct.redOffset,ct.greenOffset,ct.blueOffset]};
        }
        private function startSample():void {
            dismiss();w.onPause=true;r.render();var loc:*=w.loc;
            current={prefix:"sample-"+(samples.length+1),land:w.game.curLandId,room:loc.id,backwall:loc.backwall,backform:loc.backform,
                transpFon:loc.transpFon,fonClass:getQualifiedClassName(w.grafon.visFon),sky:loc.sky,darkness:loc.darkness,color:loc.color,
                width:loc.spaceX,height:loc.spaceY,lamps:r.lamps.length,onLamps:0,windows:r.environment.openings.length,
                zones:r.darkZones.length,regions:r.environment.regions.length,profile:r.environment.profile(w.gg.X,w.gg.Y).kind,
                ambient:r.ambient,headlamp:r.store.data.headlamp,rvEnabled:rv.get(),layers:[],fixtures:[],backObjects:{}};
            samples.push(current);
            for each(var bo:* in loc.backobjs) {var key:String=String(bo.id);current.backObjects[key]=int(current.backObjects[key])+1;}
            for each(var l:Object in r.lamps){if(l.state.on && l.powered && l.state.hp>0)current.onLamps++;current.fixtures.push({type:l.type,on:l.state.on,power:l.power,brightness:l.state.atmosphere.brightness,mode:l.state.atmosphere.mode});}
            for(var i:int=0;i<w.grafon.visual.numChildren;i++)current.layers.push(layer(w.grafon.visual.getChildAt(i)));
            current.fonLayer=layer(w.grafon.visFon);current.visual=layer(w.grafon.visual);
            picture("actual");r.store.data.headlamp=false;r.render();picture("fixed-rv");
            rv.set(false);phase=3;frames=0;
        }
        private function layerRaster(o:DisplayObject,bounds:Rectangle,cell:int):BitmapData {
            var result:BitmapData=new BitmapData(Math.ceil(bounds.width/cell),Math.ceil(bounds.height/cell),true,0);
            var m:Matrix=o.transform.concatenatedMatrix.clone(),inverse:Matrix=w.grafon.visual.transform.concatenatedMatrix.clone();inverse.invert();m.concat(inverse);
            m.translate(-bounds.x,-bounds.y);m.scale(1/cell,1/cell);result.draw(o,m,null,null,null,true);return result;
        }
        private function auditField():void {
            var g:*=w.grafon,bounds:Rectangle=r.field.bounds.clone(),cell:int=r.field.cell;
            var back:BitmapData=layerRaster(g.visBack,bounds,cell),back2:BitmapData=layerRaster(g.visBack2,bounds,cell),front:BitmapData=layerRaster(g.visFront,bounds,cell);
            var field:BitmapData=r.field.data,original:BitmapData=field.clone();
            var map:BitmapData=new BitmapData(field.width,field.height,false,0),points:Array=[];
            var missing:int=0,open:int=0,recognized:int=0;
            // Evidence of native transparency, not proof of physical outdoor connectivity.
            for(var x:int=0;x<field.width;x++)for(var y:int=0;y<field.height;y++) {
                var wx:Number=bounds.x+(x+.5)*cell,wy:Number=bounds.y+(y+.5)*cell;
                var tx:int=Math.floor(wx/40),ty:int=Math.floor(wy/40);
                if(tx<0||ty<0||tx>=w.loc.spaceX||ty>=w.loc.spaceY)continue;
                var opacity:Number=1-(1-(back.getPixel32(x,y)>>>24)/255)*(1-(back2.getPixel32(x,y)>>>24)/255)*(1-(front.getPixel32(x,y)>>>24)/255);
                var sky:Boolean=r.environment.skyAt(tx,ty),free:Boolean=w.loc.space[tx][ty].opac<.99;
                if(sky)recognized++;
                if(opacity<.3 && free){open++;if(!sky)missing++;map.setPixel(x,y,sky?0x44cc77:0xff6655);}else if(sky)map.setPixel(x,y,0x336688);
                var s:Point=g.visual.localToGlobal(new Point(wx,wy));
                if(x%2==0 && y%2==0 && s.x>=0 && s.x<main.stage.stageWidth && s.y>=0 && s.y<main.stage.stageHeight)
                    points.push({x:int(s.x),y:int(s.y),wx:wx,wy:wy,opaque:opacity>.9,opening:opacity<.3 && free,
                        missed:opacity<.3 && free && !sky,solid:w.loc.space[tx][ty].phis!=0,sky:sky,field:r.field.sample(wx,wy)});
            }
            current.raster={bounds:[bounds.x,bounds.y,bounds.width,bounds.height],cell:cell,openSamples:open,missedSamples:missing,skySamples:recognized,points:points};
            png(current.prefix+"-apertures",map);png(current.prefix+"-field",original);
            // Concept comparison: only the diagnosed Manehattan backdrop apertures become .70 sources.
            // No production code, propagation or gameplay changes; silhouette receive-light intentionally not approximated.
            if(current.land=="random_mane") {
                for(x=0;x<field.width;x++)for(y=0;y<field.height;y++)if(map.getPixel(x,y)==0xff6655) {
                    var c:uint=field.getPixel(x,y);field.setPixel(x,y,(Math.max((c>>16)&255,178)<<16)|(Math.max((c>>8)&255,178)<<8)|Math.max(c&255,178));
                }
                picture("aperture-concept");field.copyPixels(original,original.rect,new Point());
            }
            // Check maximum possible benefit of restoring the original scene under the new light layer.
            r.field.bitmap.visible=false;picture("mask-off");r.field.bitmap.visible=true;
            back.dispose();back2.dispose();front.dispose();map.dispose();original.dispose();
        }
        private function controlled():void {
            // RV was disabled through its own settings; turn off only native exploration fog for all controlled images.
            w.grafon.visLight.visible=false;r.render();current.controlledVisual=layer(w.grafon.visual);picture("formal");auditField();
            var ambient:Number=r.ambient,brightness:Number=r.atmosphere.settings.brightness;
            r.ambient=ambient*1.25;r.render();picture("ambient125");r.ambient=ambient;
            r.atmosphere.settings.brightness=1.5;r.render();picture("lamps150");r.atmosphere.settings.brightness=brightness;r.render();
            r.store.data.headlamp=current.headlamp;r.setEnabled(false);
            w.cam.setZoom();w.cam.calc(w.gg);w.grafon.visLight.visible=false;current.nativeVisual=layer(w.grafon.visual);picture("native");
            if(samples.length==1)textures();
            write("progress.json",JSON.stringify(samples,null,2));
            r.setEnabled(true);rv.set(current.rvEnabled);phase=4;frames=0;
        }
        private function textures():void {
            var rows:Array=[];
            for each(var id:String in ["tWindows","tWindows2","tTower","tBackWall","tStConcrete","tEncl3","tSteklo"]) {
                var b:BitmapData=w.grafon.getObj(id) as BitmapData;if(!b)continue;
                var clear:int=0,partial:int=0;
                for(var x:int=0;x<b.width;x++)for(var y:int=0;y<b.height;y++){var a:uint=b.getPixel32(x,y)>>>24;if(a<77)clear++;else if(a<255)partial++;}
                png("texture-"+id,b);rows.push({id:id,width:b.width,height:b.height,transparent:clear,partial:partial,total:b.width*b.height});
            }
            write("textures.json",JSON.stringify(rows,null,2));
        }
        private function travel():void {
            if(index>=targets.length){finish();return;}
            dismiss();w.pers.healAll();w.onPause=false;
            if(targets[index]=="random_canter")w.game.triggers["encounter_way"]=1;
            if(targets[index]=="random_encl")w.game.triggers["encounter_post"]=1;
            w.game.beginMission(targets[index]);phase=2;frames=0;
        }
        private function step(e:Event):void {
            try {
                var W:Class=getDefinitionByName("fe.World") as Class;w=W["w"];
                if(w && w.verror && w.verror.visible)throw new Error(w.verror.txt.text);
                if(getTimer()-started>560000)throw new Error("timeout phase="+phase+" target="+targets[index]);
                if(phase==0 && w && w.allLandsLoaded && w.textLoaded && w.mm){w.mm.mainMenuOff();w.newGame(-1,"LP",{propusk:true});phase=1;}
                else if(phase>0 && w.gg && w.loc && w.loc.active && w.allStat==1 && w.t_exit==0) {
                    var c:*=main.getChildByName("LightAndDarknessCarrier");if(!c)return;r=c.ladAPI.runtime;
                    if(c.ladAPI.version!="0.4.1")throw new Error("unexpected production version");
                    if(!rv)rv=findRV();if(!rv)return;
                    if(phase==3){if(++frames>=8)controlled();return;}
                    if(phase==4){if(++frames>=8 && r.location===w.loc){if(samples.length>1)index++;travel();}return;}
                    if(r.location!==w.loc)return;
                    if(phase==2 && (w.game.curLandId!=targets[index] || w.land.act.id!=targets[index]))return;
                    if(++frames>=35)startSample();
                }
            }catch(error:*) {finish(String(error)+" "+error.getStackTrace());}
        }
    }
}
