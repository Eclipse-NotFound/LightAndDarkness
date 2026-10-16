package {
    import flash.desktop.NativeApplication;
    import flash.display.Sprite;
    import flash.display.BitmapData;
    import flash.display.PNGEncoderOptions;
    import flash.events.Event;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.utils.getDefinitionByName;
    import flash.utils.getTimer;

    /** Diagnosis only: invokes the installed runtime, without embedding lad or fe classes. */
    public class LightBorderProbe extends Sprite {
        private static var probe:LightBorderProbe;
        private var main:*,world:*,runtime:*;
        private var phase:int=0,frames:int=0,mode:int=0,started:int;
        private var rows:Array=[],checks:Array=[];
        public function LightBorderProbe() {}
        public static function init(root:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-border-")!=0)return;
            probe=new LightBorderProbe();probe.main=root;probe.started=getTimer();
            root.stage.addEventListener(Event.ENTER_FRAME,probe.frame,false,-150);
        }
        private function log(value:String):void {
            var out:FileStream=new FileStream();out.open(File.applicationStorageDirectory.resolvePath("border-test.log"),FileMode.APPEND);
            out.writeUTFBytes(value+"\n");out.close();
        }
        private function check(ok:Boolean,label:String):void {
            checks.push({pass:ok,label:label});log((ok?"PASS ":"FAIL ")+label);if(!ok)throw new Error(label);
        }
        private function state():Object {
            var g:*=world.grafon,c:*=world.cam;
            return {zoom:c.isZoom,scale:c.scaleV,visualX:world.visual.x,visualY:world.visual.y,
                top:g.ramT.scaleY,bottom:g.ramB.scaleY,left:g.ramL.scaleX,right:g.ramR.scaleX,
                room:world.loc.id,land:world.game.curLandId,lamps:runtime.lamps.length,
                width:main.stage.stageWidth,height:main.stage.stageHeight};
        }
        private function picture(name:String):BitmapData {
            var data:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);
            data.draw(main.stage);
            var out:FileStream=new FileStream();out.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);
            out.writeBytes(data.encode(data.rect,new PNGEncoderOptions()));out.close();return data;
        }
        private function revealed(before:BitmapData,after:BitmapData):int {
            var count:int=0;
            for(var y:int=80;y<before.height-20;y++)for(var x:int=0;x<before.width;x++) {
                if(before.getPixel(x,y)==0 && after.getPixel(x,y)!=0)count++;
            }
            return count;
        }
        private function finish(error:String=""):void {
            main.stage.removeEventListener(Event.ENTER_FRAME,frame);
            var out:FileStream=new FileStream();out.open(File.applicationStorageDirectory.resolvePath("border-report.json"),FileMode.WRITE);
            out.writeUTFBytes(JSON.stringify({status:error?"failed":"passed",error:error,rows:rows,checks:checks,
                applicationID:NativeApplication.nativeApplication.applicationID,elapsedMs:getTimer()-started,
                boundary:"Isolated new game; production runtime toggle; only camera zoom reapplied for diagnosis. No production file or real save modified."},null,2));out.close();
            log(error?"FAIL "+error:"SUITE_PASS");
        }
        private function frame(event:Event):void {
            try {
                var World:Class=getDefinitionByName("fe.World") as Class;world=World["w"];
                if(world && world.verror && world.verror.visible)throw new Error(world.verror.txt.text);
                if(getTimer()-started>160000)throw new Error("timeout phase="+phase);
                if(phase==0 && world && world.allLandsLoaded && world.textLoaded && world.mm) {
                    world.mm.mainMenuOff();world.newGame(-1,"LP",{propusk:true});phase=1;
                } else if(phase==1 && world.gg && world.loc && world.loc.active && world.allStat==1) {
                    var carrier:*=main.getChildByName("LightAndDarknessCarrier");if(!carrier)return;
                    runtime=carrier.ladAPI.runtime;if(runtime.location!==world.loc)return;
                    if(++frames<8)return;
                    world.gui.dialText(null);world.gui.guiPause=false;world.gui.dialScript.running=false;world.onPause=true;
                    rows.push({entry:state()});picture("entry").dispose();
                    check(runtime.lamps.length>0,"native new-game room contains converted fixtures");
                    runtime.setEnabled(false);world.cam.setZoom(mode);world.cam.calc(world.gg);runtime.setEnabled(true);
                    phase=2;frames=0;
                } else if(phase==2 && runtime.location===world.loc && ++frames>=4) {
                    var g:*=world.grafon;
                    var row:Object={mode:mode,broken:state()};rows.push(row);
                    check(g.ramT.scaleY==2 && g.ramL.scaleX==2,"production fixture attach resets native borders mode="+mode);
                    var broken:BitmapData=picture("mode"+mode+"-broken");
                    var borders:Array=[g.ramT,g.ramB,g.ramL,g.ramR],visibility:Array=[];
                    for each(var border:* in borders){visibility.push(border.visible);border.visible=false;}
                    var hidden:BitmapData=picture("mode"+mode+"-borders-hidden");
                    row.revealedByHidingBorders=revealed(broken,hidden);
                    for(var i:int=0;i<borders.length;i++)borders[i].visible=visibility[i];
                    world.cam.setZoom();
                    row.restored=state();
                    var restored:BitmapData=picture("mode"+mode+"-camera-restored");
                    row.revealedByCamera=revealed(broken,restored);
                    check(g.ramT.scaleY<0 && g.ramL.scaleX<0,"same zoom restores outward-facing native borders mode="+mode);
                    check(row.revealedByHidingBorders>1000,"native borders alone account for black scene pixels mode="+mode);
                    check(row.revealedByCamera>1000,"reapplying camera exposes missing scene pixels mode="+mode);
                    check(row.broken.zoom==row.restored.zoom && row.broken.scale==row.restored.scale && row.broken.visualX==row.restored.visualX && row.broken.visualY==row.restored.visualY,"repair preserves zoom and camera position mode="+mode);
                    broken.dispose();hidden.dispose();restored.dispose();
                    runtime.setEnabled(false);row.disabled=state();
                    check(g.ramT.scaleY==2,"disabling lighting redraws and leaves border defect mode="+mode);
                    mode++;
                    if(mode>=3){finish();return;}
                    world.cam.setZoom(mode);world.cam.calc(world.gg);runtime.setEnabled(true);frames=0;
                }
            }catch(error:*){finish(String(error)+" "+error.getStackTrace());}
        }
    }
}
