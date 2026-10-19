package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.Event;
    import flash.filesystem.*;
    import flash.geom.*;
    import flash.net.SharedObject;
    import flash.text.*;
    import flash.utils.*;
    public class LandmarkProbeMod extends Sprite {
        public function LandmarkProbeMod() {}
        private static var self:LandmarkProbeMod;
        private var main:*,w:*,r:*,mode:String,started:int,phase:int=0,frames:int=0;
        private var checks:int=0;
        public static function init(root:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-landmark-")!=0)return;
            self=new LandmarkProbeMod();self.main=root;self.started=getTimer();
            var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("landmark-mode.txt"),FileMode.READ);self.mode=f.readUTFBytes(f.bytesAvailable);f.close();
            if(self.mode=="regression" || self.mode=="cold")LightAndDarknessTest.init(root);
            root.stage.addEventListener(Event.ENTER_FRAME,self.step,false,-150);
        }
        private function write(name:String,text:String):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);f.writeUTFBytes(text);f.close();}
        private function png(name:String,b:BitmapData):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);f.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));f.close();b.dispose();}
        private function check(ok:Boolean,label:String):void {if(!ok)throw new Error(label);checks++;var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("checks.log"),FileMode.APPEND);f.writeUTFBytes("PASS "+label+"\n");f.close();}
        private function finish(error:String=""):void {
            main.stage.removeEventListener(Event.ENTER_FRAME,step);
            write("landmark.json",JSON.stringify({error:error,mode:mode,version:r?main.getChildByName("LightAndDarknessCarrier").ladAPI.version:"",roomsLoad:w?w.roomsLoad:0,checks:checks,samples:[],loader:SharedObject.getLocal("ModLoader","/").data},null,2));
            write("landmark.done",error?"FAIL "+error:"PASS");NativeApplication.nativeApplication.exit(error?1:0);
        }
        private function tree(node:DisplayObject,depth:int=0):Object {
            var b:Rectangle=node.getBounds(node),a:Object={name:node.name,type:getQualifiedClassName(node),x:node.x,y:node.y,alpha:node.alpha,visible:node.visible,bounds:b.toString()};
            if(node is MovieClip){a.frame=MovieClip(node).currentFrame;a.frames=MovieClip(node).totalFrames;a.labels=MovieClip(node).currentLabels;}
            if(node is DisplayObjectContainer && depth<5){a.children=[];for(var i:int=0;i<DisplayObjectContainer(node).numChildren;i++)a.children.push(tree(DisplayObjectContainer(node).getChildAt(i),depth+1));}return a;
        }
        private function atlas():void {
            var board:Sprite=new Sprite(),rows:Array=[],CP:Class=getDefinitionByName("fe.loc.CheckPoint") as Class;
            board.graphics.beginFill(0x30343a);board.graphics.drawRect(0,0,1200,900);board.graphics.endFill();
            var items:Array=[];
            for(var state:int=0;state<4;state++) {
                var cp:*=new CP(w.loc,"checkpoint",400,600);
                cp.vis.osn.gotoAndStop(state==0?1:state==1?"reopen":"open");cp.vis.fiol.gotoAndStop(state==3?25:1);
                items.push({label:"checkpoint "+["closed","reopen","open","teleport"][state],vis:cp.vis});
            }
            for each(var id:String in ["exit","doorprob","doorboss","doorout"]) {
                var v:MovieClip=w.grafon.getObj("vis"+id,1);v.stop();items.push({label:id,vis:v});
            }
            for(var n:int=0;n<items.length;n++) {
                v=items[n].vis;rows.push({id:items[n].label,tree:tree(v)});
                var bounds:Rectangle=v.getBounds(v),scale:Number=Math.min(1.7,260/bounds.width,350/bounds.height);
                v.scaleX=v.scaleY=scale;v.x=n%4*300+150-(bounds.x+bounds.width/2)*scale;v.y=int(n/4)*450+65-bounds.y*scale;board.addChild(v);
                var label:TextField=new TextField();label.defaultTextFormat=new TextFormat("Arial",15,0xffffff);label.width=295;label.text=items[n].label;label.x=n%4*300+5;label.y=int(n/4)*450+10;board.addChild(label);
            }
            var b:BitmapData=new BitmapData(1200,900,false,0);b.draw(board);png("native-atlas",b);write("native-tree.json",JSON.stringify(rows,null,2));
        }
        private function step(e:Event):void {
            try {
                var World:Class=getDefinitionByName("fe.World") as Class;w=World["w"];
                if(w && w.verror && w.verror.visible)throw new Error(w.verror.txt.text);
                var carrier:*=main.getChildByName("LightAndDarknessCarrier");if(carrier)r=carrier.ladAPI.runtime;
                if(getTimer()-started>300000)throw new Error("timeout");
                if(mode=="regression" || mode=="cold") {
                    var file:File=File.applicationStorageDirectory.resolvePath("test.log");if(!file.exists)return;
                    var f:FileStream=new FileStream();f.open(file,FileMode.READ);var txt:String=f.readUTFBytes(f.bytesAvailable);f.close();
                    if(txt.indexOf(" FAIL ")>=0)throw new Error(txt);if(txt.indexOf(" SUITE_PASS")>=0)finish();return;
                }
                if(phase==0 && w && w.allLandsLoaded && w.textLoaded && w.mm){w.mm.mainMenuOff();w.newGame(-1,"LP",{propusk:true});phase=1;}
                else if(phase==1 && r && w.gg && w.loc && w.loc.active && w.allStat==1 && w.t_exit==0 && r.location===w.loc && ++frames>10) {
                    w.gui.dialText(null);w.gui.guiPause=false;w.gui.dialScript.running=false;w.onPause=true;
                    atlas();if(mode=="verify")LandmarkChecks.run(w,r,main,check,png);finish();
                }
            }catch(error:*){finish(String(error)+" "+error.getStackTrace());}
        }
    }
}
