package {
    import flash.desktop.NativeApplication;
    import flash.display.Sprite;
    import flash.display.BitmapData;
    import flash.display.PNGEncoderOptions;
    import flash.events.Event;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.geom.Rectangle;
    import flash.net.SharedObject;
    import flash.utils.getDefinitionByName;
    import flash.utils.getTimer;

    /** Investigation only: uses the installed LAD classes; never changes production files. */
    public class MapLightingSurveyMod extends Sprite {
        public function MapLightingSurveyMod() {}
        private static var instance:MapLightingSurveyMod;
        private var main:*,w:*,r:*;
        private var phase:int=0,frames:int=0,started:int,index:int=0;
        private var targets:Array=["surf","random_mane","mtn","stable_pi"];
        private var samples:Array=[],catalog:Array=[];
        public static function init(root:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-survey-")!=0)return;
            instance=new MapLightingSurveyMod();instance.main=root;instance.started=getTimer();
            root.stage.addEventListener(Event.ENTER_FRAME,instance.step,false,-150);
        }
        private function write(name:String,text:String):void {
            var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);
            f.writeUTFBytes(text);f.close();
        }
        private function picture(name:String):void {
            var b:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);
            b.draw(main.stage);
            var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);
            f.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));f.close();b.dispose();
        }
        private function finish(error:String=""):void {
            main.stage.removeEventListener(Event.ENTER_FRAME,step);
            write("survey.json",JSON.stringify({error:error,roomsLoad:w.roomsLoad,boxDamage:w.constructor.boxDamage,
                applicationID:NativeApplication.nativeApplication.applicationID,loader:SharedObject.getLocal("ModLoader","/").data,catalog:catalog,samples:samples,
                boundary:"One isolated random new game, installed LAD only. Floor-adjacent empty tile centers; not navigation reachability. Revealed fog only in screenshots. No FPS claim."},null,2));
            write("survey.done",error?"FAIL "+error:"PASS");
            NativeApplication.nativeApplication.exit(error?1:0);
        }
        private function dismiss():void {
            w.gui.dialText(null);w.gui.guiPause=false;w.gui.dialScript.running=false;
        }
        private function metrics():Object {
            r.render();
            var Field:Class=r.field.constructor as Class,field:*=new Field();
            var rect:Rectangle=new Rectangle(0,0,w.loc.spaceX*40,w.loc.spaceY*40);
            field.render(w.loc,rect,r.lights(rect),w.loc.sky?Math.max(0.6,r.ambient):r.ambient,
                r.atmosphere.settings.darkZones?r.darkZones:null,r.atmosphere.settings.darkness);
            var v:Array=[],low:int=0,nearBlack:int=0;
            for(var x:int=1;x<w.loc.spaceX-1;x++)for(var y:int=1;y<w.loc.spaceY-1;y++) {
                if(w.loc.space[x][y].phis==0 && w.loc.space[x][y-1].phis==0 && w.loc.space[x][y+1].phis>0) {
                    var n:Number=field.sample(x*40+20,y*40+20);v.push(n);if(n<0.2)low++;if(n<0.05)nearBlack++;
                }
            }
            field.clear();v.sort(Array.NUMERIC);
            return {points:v.length,min:v.length?v[0]:null,median:v.length?v[int(v.length/2)]:null,
                below20:low,below5:nearBlack,below20Fraction:v.length?low/v.length:null};
        }
        private function sample():void {
            dismiss();w.onPause=true;
            var loc:*=w.loc, row:Object={land:w.game.curLandId,room:loc.id,backwall:loc.backwall,sky:loc.sky,
                darkness:loc.darkness,color:loc.color,base:loc.base,black:loc.black,lightOn:loc.lightOn,
                width:loc.spaceX,height:loc.spaceY,lamps:r.lamps.length,zones:r.darkZones.length,
                ambient:r.ambient,time:r.atmosphereTime,fixtures:[]};samples.push(row);
            for each(var lamp:Object in r.lamps) row.fixtures.push({id:lamp.type,frame:lamp.bo.frame,on:lamp.state.on,
                mode:lamp.state.atmosphere.mode,brightness:lamp.state.atmosphere.brightness,power:lamp.power});
            row.defaultHeadlamp=metrics();
            var oldHead:Boolean=r.store.data.headlamp,oldZones:Boolean=r.atmosphere.settings.darkZones;
            r.store.data.headlamp=false;row.noHeadlamp=metrics();
            r.atmosphere.settings.darkZones=false;row.noHeadlampNoPockets=metrics();
            r.atmosphere.settings.darkZones=oldZones;r.store.data.headlamp=oldHead;
            // Explicitly reveal native fog in this disposable scene to isolate illumination.
            for(var x:int=0;x<loc.spaceX;x++)for(var y:int=0;y<loc.spaceY;y++) loc.space[x][y].visi=loc.space[x][y].t_visi=1;
            w.grafon.setLight();w.cam.setZoom();w.cam.calc(w.gg);
            r.render();picture("sample-"+samples.length+"-lad-headlamp");
            r.store.data.headlamp=false;r.render();picture("sample-"+samples.length+"-lad-fixed");
            r.store.data.headlamp=oldHead;r.setEnabled(false);w.cam.setZoom();w.cam.calc(w.gg);
            picture("sample-"+samples.length+"-native");r.setEnabled(true);
            write("progress.json",JSON.stringify(samples,null,2));
        }
        private function travel():void {
            if(index>=targets.length){finish();return;}
            var target:String=targets[index];
            if(w.game.curLandId==target){index++;travel();return;}
            dismiss();w.pers.healAll();w.onPause=false;w.game.beginMission(target);phase=2;frames=0;
        }
        private function step(e:Event):void {
            try {
                var World:Class=getDefinitionByName("fe.World") as Class;w=World["w"];
                if(w && w.verror && w.verror.visible)throw new Error(w.verror.txt.text);
                if(getTimer()-started>200000)throw new Error("timeout phase="+phase+" target="+targets[index]);
                if(phase==0 && w && w.allLandsLoaded && w.textLoaded && w.mm) {
                    for(var id:String in w.landData) {
                        var pool:XML=w.landData[id].allroom;
                        catalog.push({land:id,rooms:pool.room.length(),backs:pool.room.back.length()});
                    }
                    w.mm.mainMenuOff();w.newGame(-1,"LP",{propusk:true});phase=1;
                } else if(phase>0 && w.gg && w.loc && w.loc.active && w.allStat==1 && w.t_exit==0) {
                    var carrier:*=main.getChildByName("LightAndDarknessCarrier");if(!carrier)return;
                    r=carrier.ladAPI.runtime;if(r.location!==w.loc)return;
                    if(phase==2 && (w.game.curLandId!=targets[index] || w.land.act.id!=targets[index]))return;
                    if(++frames<8)return;
                    sample();if(phase==2)index++;travel();
                }
            }catch(error:*) {finish(String(error)+" "+error.getStackTrace());}
        }
    }
}
