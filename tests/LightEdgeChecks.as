package {
    import flash.display.Sprite;
    import flash.display.BitmapData;
    import flash.display.PNGEncoderOptions;
    import flash.display.StageQuality;
    import flash.events.Event;
    import flash.geom.Rectangle;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.utils.getTimer;
    import lad.LadLightFieldBeforeAA;
    public class LightEdgeChecks {
        private var Field:Class;
        public function LightEdgeChecks(field:Class) {Field=field;}
        private function log(s:String):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("edge-test.log"),FileMode.APPEND);f.writeUTFBytes(s+"\n");f.close();}
        private function check(ok:Boolean,s:String):void {if(!ok) throw new Error(s);log("PASS "+s);}
        private function picture(field:*,name:String):BitmapData {
            var pane:Sprite=new Sprite();pane.graphics.beginFill(0xffffff);pane.graphics.drawRect(0,0,800,600);pane.graphics.endFill();pane.addChild(field.bitmap);
            var data:BitmapData=new BitmapData(800,600,false,0);data.draw(pane);
            var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);file.writeBytes(data.encode(data.rect,new PNGEncoderOptions()));file.close();
            return data;
        }
        private function jumps(data:BitmapData):Number {
            var highest:Number=0;
            for(var x:int=200;x<540;x++) for(var y:int=80;y<520;y++) {
                var v:int=data.getPixel(x,y)&255;
                highest=Math.max(highest,Math.abs(v-int(data.getPixel(x+1,y)&255)),Math.abs(v-int(data.getPixel(x,y+1)&255)));
            }
            return highest;
        }
        public function run():void {
            try {
                var map:Object={spaceX:30,spaceY:20,space:[]};
                for(var x:int=0;x<30;x++){map.space[x]=[];for(var y:int=0;y<20;y++)map.space[x][y]=LightCoreChecks.tile(x,y);}
                var view:Rectangle=new Rectangle(0,0,800,600);
                var light:Object={id:"headlamp",x:180,y:300,radius:440,color:0xffffff,power:1,angle:-0.27,cone:Math.PI*0.58};
                var old:*=new LadLightFieldBeforeAA(),fixed:*=new Field();
                old.render(map,view,[light],0.14);fixed.render(map,view,[light],0.14);
                log("BASELINE smoothing="+old.bitmap.smoothing+" current="+fixed.bitmap.smoothing);
                check(!old.bitmap.smoothing,"deployed baseline reproduces lost smoothing after allocation");
                check(fixed.bitmap.smoothing,"current field retains smoothing after allocation");
                check(old.data.compare(fixed.data)===0,"display fix preserves illumination raster exactly");
                var before:BitmapData=picture(old,"before"),after:BitmapData=picture(fixed,"after");
                var a:Number=jumps(before),b:Number=jumps(after);log("EDGE max adjacent jump before="+a+" after="+b);
                check(b<a*0.35,"visible hard pixel steps reduced");before.dispose();after.dispose();
                for each(var angle:Number in [-0.7,0.17,1.2,2.8]) {
                    light.angle=angle;old.render(map,view,[light],0.14);fixed.render(map,view,[light],0.14);
                    check(old.data.compare(fixed.data)===0,"rotated beam keeps gameplay raster angle="+angle);
                }
                light.angle=0;for(y=0;y<20;y++) map.space[10][y].opac=1;
                old.render(map,view,[light],0.14);fixed.render(map,view,[light],0.14);
                check(old.data.compare(fixed.data)===0,"wall occlusion unchanged");
                check(fixed.sample(460,300)<0.15,"wall shadow interior stays dark");
                after=picture(fixed,"wall-after");check((after.getPixel(424,300)&255)<=36,"display does not illuminate wall shadow interior");after.dispose();
                view.width=960;fixed.render(map,view,[light],0.14);check(fixed.bitmap.smoothing,"resize keeps smoothing");
                fixed.clear();fixed.render(map,view,[light],0.14);check(fixed.bitmap.smoothing,"location rebuild keeps smoothing");
                var timings:Array=[];
                for(var pass:int=0;pass<4;pass++) {
                    var field:*=pass%2?fixed:old;var start:int=getTimer();
                    for(var i:int=0;i<180;i++){light.angle=i/90;field.render(map,view,[light],0.14);}
                    timings.push(getTimer()-start);
                }
                log("PERF alternating baseline/fixed 180 renders total ms="+timings.join(","));
                old.clear();fixed.clear();log("SUITE_PASS");
            } catch(error:*) {log("FAIL "+error+" "+error.getStackTrace());}
        }
    }
}
