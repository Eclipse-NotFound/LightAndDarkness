package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.Event;
    import flash.filesystem.*;
    import flash.geom.*;
    import flash.net.SharedObject;
    import flash.text.*;
    import flash.utils.*;
    public class LightMachineProbeMod extends Sprite {
        private static var self:LightMachineProbeMod;
        private var main:*,world:*,runtime:*,phase:int=0,started:int,frames:int=0;
        private var mode:String="atlas",checks:int=0,report:String="",finished:int=0;
        private var names:Array=["turret","landturret","wturret","armturret","cturret","bossturret","hturret","hturret2","msp","ttur"];
        public static function init(root:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-machine-")!=0)return;
            self=new LightMachineProbeMod();self.main=root;self.started=getTimer();
            var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("machine-mode.txt"),FileMode.READ);self.mode=f.readUTFBytes(f.bytesAvailable);f.close();
            if(self.mode=="regression" || self.mode=="baseline") LightAndDarknessTest.init(root);
            root.stage.addEventListener(Event.ENTER_FRAME,self.frame,false,-150);
        }
        private function write(name:String,value:String):void {
            var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);f.writeUTFBytes(value);f.close();
        }
        private function png(name:String,data:BitmapData):void {
            var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);f.writeBytes(data.encode(data.rect,new PNGEncoderOptions()));f.close();data.dispose();
        }
        private function check(value:Boolean,label:String):void {
            if(!value) throw new Error(label);
            report+="PASS "+label+"\n";checks++;
        }
        private function unit(kind:String):* {
            var Unit:Class=getDefinitionByName("fe.unit.Unit") as Class;
            var u:*=Unit["create"](kind,5,new XML("<u tr='1'/>"),null,kind=="ttur"?"1":null);
            u.putLoc(world.loc,400,600);u.animate();u.setVisPos();
            world.grafon.visObjs[1].addChild(u.vis);return u;
        }
        private function lightState(u:*,frame:int):void {u.vis.osn.gotoAndStop(1);u.vis.osn.light.gotoAndStop(frame);}
        private function collect(units:Array,view:Rectangle=null):Array {
            var old:Array=world.loc.units;world.loc.units=units;
            var result:Array;
            try {result=runtime.machines.lights(world.loc,world.grafon.visual,view || new Rectangle(0,0,2000,1600));}
            finally {world.loc.units=old;}
            return result;
        }
        private function drop(u:*):void {if(u.vis.parent)u.vis.parent.removeChild(u.vis);}
        private function verify():void {
            var expected:String="0.3.2",file:File=File.applicationDirectory.resolvePath("expected-version.txt");
            if(file.exists){var stream:FileStream=new FileStream();stream.open(file,FileMode.READ);expected=stream.readUTFBytes(stream.bytesAvailable);stream.close();}
            check(main.getChildByName("LightAndDarknessCarrier").ladAPI.version==expected,"production version "+expected);
            for(var n:int=0;n<8;n++) {
                var u:*=unit(names[n]);
                for(var f:int=1;f<=5;f++) {
                    lightState(u,f);var values:Array=collect([u]);
                    check(values.length==(f==1?0:1),names[n]+" native indicator frame "+f);
                    if(f>1)check(values[0].color==(f==2?0xffdf55:f==4?0xff5246:0xffad48),names[n]+" color follows art "+f);
                }
                lightState(u,2);var initial:Object=collect([u])[0];u.vis.x+=40;u.vis.y-=20;
                var moved:Object=collect([u])[0];check(Math.abs(moved.x-initial.x-40)<0.1 && Math.abs(moved.y-initial.y+20)<0.1,names[n]+" follows native transform");
                var hp:Number=u.hp,sost:int=u.sost;u.sost=3;check(collect([u]).length==0,names[n]+" dead has no glow");u.sost=sost;u.hp=0;
                check(collect([u]).length==0,names[n]+" zero HP has no glow");u.hp=hp;
                u.vis.visible=false;check(collect([u]).length==0,names[n]+" invisible has no glow");u.vis.visible=true;
                u.hack(0);u.animate();check(collect([u]).length==0,names[n]+" native shutdown extinguishes light");
                if(n>=6){lightState(u,4);var stale:*=u.vis.osn.light;u.vis.osn.gotoAndStop(6);check(collect([u]).length==0,names[n]+" retraction ignores stale lamp reference");}
                drop(u);
            }
            // All seven native weapon variants retain their own indicator independently of the barrel.
            u=unit("turret");
            for(n=1;n<=7;n++){u.tr=n;u.animate();lightState(u,2);u.vis.osn.puha.rotation=n*20;check(collect([u]).length==1,"weapon variant "+n);}
            u.vis.alpha=0;check(collect([u]).length==0,"transparent unit has no glow");u.vis.alpha=1;
            u.disabled=true;check(collect([u]).length==0,"disabled unit has no glow");u.disabled=false;
            check(collect([u],new Rectangle(3000,3000,200,200)).length==0,"offscreen sources culled");
            drop(u);check(collect([u]).length==0,"removed visual has no glow");
            u=unit("msp");u.vis.osn.gotoAndStop("stay");check(collect([u]).length==0,"spider dormant bulb is unlit");
            for each(var label:String in ["wake","walk","jump"]) {
                u.vis.osn.gotoAndStop(label);var body:MovieClip=u.vis.osn.getChildAt(0) as MovieClip;
                for(f=1;f<=body.totalFrames;f++) {
                    body.gotoAndStop(f);values=collect([u]);
                    check(values.length==1,"spider "+label+" animation "+f);
                    check(values[0].color==(label=="wake"?0xffdc3e:0xff5546),"spider "+label+" native color "+f);
                }
            }
            u.vis.osn.gotoAndStop("wake");u.vis.x=500;u.vis.y=500;
            for each(var angle:int in [0,90,180,-90])for each(var facing:int in [-1,1]) {
                u.vis.rotation=angle;u.vis.scaleX=facing;values=collect([u]);
                var local:Point=u.vis.globalToLocal(world.grafon.visual.localToGlobal(new Point(values[0].x,values[0].y)));
                check(Math.abs(local.x)<1 && Math.abs(local.y+25.9)<1,"spider mounting "+angle+" facing "+facing);
            }
            u.sost=3;check(collect([u]).length==0,"spider death removes glow");drop(u);
            u=unit("ttur");check(collect([u]).length==0,"Thunderhead unlit metal mount stays dark");
            u.mega();values=collect([u]);check(values.length==1 && values[0].color==0x78baff,"Thunderhead active force field spills blue");drop(u);
            // Native damage path, not just a synthetic death flag.
            u=unit("landturret");lightState(u,4);u.invulner=false;u.damage(1000000,0,null,false);
            check(collect([u]).length==0,"native lethal damage extinguishes turret");drop(u);
            var crowd:Array=[];
            for(n=0;n<40;n++){u=unit("turret");u.vis.x=u.X=400+n;lightState(u,2);crowd.push(u);}
            check(collect(crowd).length==32,"visible source budget is bounded at 32");
            for each(u in crowd)drop(u);
            check(collect([{id:"turret",loc:world.loc,disabled:false,sost:1,hp:100}]).length==0,"unrelated class cannot masquerade as turret");
            check(collect([]).length==0,"removed units leave no retained sources");
            runtime.machines.clear();check(collect([]).length==0,"clear removes scene references");
            rasterChecks();gallery();
            runtime.setAtmospherePreference("machines",false);
            check(!runtime.atmosphere.settings.machines && !JSON.parse(world.game.triggers["lightanddarkness.state.v1"]).atmosphereSettings.machines,"toggle persists in native save payload");
            runtime.setAtmospherePreference("machines",true);
            liveScene();
        }
        private function liveScene():void {
            var u:*=unit("landturret"),mine:*=unit("msp");
            u.setPos(world.gg.X+160,world.gg.Y);u.setVisPos();lightState(u,2);
            mine.setPos(world.gg.X+70,world.gg.Y);mine.setVisPos();mine.vis.osn.gotoAndStop("wake");
            world.loc.units.push(u,mine);runtime.store.data.headlamp=false;runtime.ambient=0.08;
            for each(var lamp:Object in runtime.lamps)lamp.state.on=false;
            runtime.setAtmospherePreference("darkZones",false);
            runtime.setAtmospherePreference("machines",false);
            var count:int=0;for each(var off:Object in runtime.lights())if(String(off.id).indexOf("machine-")==0)count++;
            check(count==0,"disabled feature emits no runtime lights");
            var before:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);before.draw(main.stage);
            runtime.setAtmospherePreference("machines",true);
            count=0;for each(var on:Object in runtime.lights())if(String(on.id).indexOf("machine-")==0)count++;
            check(count>=2,"runtime integrates native turret and spider lights");
            var after:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);after.draw(main.stage);
            var diff:*=before.compare(after);check(diff is BitmapData,"native scene pixels change with microglow enabled");if(diff is BitmapData)diff.dispose();
            png("game-microglow-off",before);png("game-microglow-on",after);
        }
        private function grid(w:int,h:int):Object {
            var loc:Object={spaceX:w,spaceY:h,space:[]};
            for(var x:int=0;x<w;x++){loc.space[x]=[];for(var y:int=0;y<h;y++)loc.space[x][y]={opac:0};}return loc;
        }
        private function rasterChecks():void {
            var u:*=unit("turret");lightState(u,4);u.X=u.vis.x=280;u.Y=u.vis.y=216.5;
            var values:Array=collect([u]),Field:Class=Object(runtime.field).constructor as Class,field:*=new Field();
            var loc:Object=grid(20,15),view:Rectangle=new Rectangle(0,0,800,600);
            field.render(loc,view,[],0.08);var dark:Number=field.sample(280,200);
            field.render(loc,view,values,0.08);check(field.sample(280,200)>dark+0.2,"microglow changes actual production illumination pixels");
            check(field.sample(400,200)==dark,"microglow does not light distant room");
            for(var y:int=0;y<15;y++)loc.space[8][y].opac=1;
            field.render(loc,view,values,0.08);
            check(field.sample(345,200)<=dark+0.01 && field.sample(300,200)>dark+0.10,"wall occludes machine spill");
            var before:Object=JSON.stringify(collect([u]));check(before==JSON.stringify(collect([u])),"paused steady source is deterministic");
            check(field.bitmap.smoothing,"existing smooth mask retained");field.clear();drop(u);
        }
        private function gallery():void {
            var board:Sprite=new Sprite(),set:Array=[],old:Array=world.loc.units;
            board.graphics.beginFill(0x777f87);board.graphics.drawRect(0,0,960,660);board.graphics.endFill();
            board.graphics.lineStyle(1,0x555e66);for(var x:int=0;x<960;x+=40){board.graphics.moveTo(x,0);board.graphics.lineTo(x,660);}for(var y:int=0;y<660;y+=40){board.graphics.moveTo(0,y);board.graphics.lineTo(960,y);}
            var labels:Array=names.slice(0,8).concat(["msp wake","msp walk","msp jump","ttur field"]);
            for(var n:int=0;n<12;n++) {
                var kind:String=n<8?names[n]:n<11?"msp":"ttur",u:*=unit(kind);
                if(n<8)lightState(u,2+n%4);else if(n<11)u.vis.osn.gotoAndStop(n==8?"wake":n==9?"walk":"jump");else u.mega();
                board.addChild(u.vis);u.X=u.vis.x=(n%4)*240+120;u.Y=u.vis.y=int(n/4)*220+175;set.push(u);
                if(n==11)u.vis.scaleX=u.vis.scaleY=0.6;
            }
            var Field:Class=Object(runtime.field).constructor as Class,field:*=new Field(),loc:Object=grid(24,17),view:Rectangle=new Rectangle(0,0,960,660);
            world.loc.units=set;
            try {var lights:Array=runtime.machines.lights(world.loc,board,view);}
            finally {world.loc.units=old;}
            field.render(loc,view,[],0.10);board.addChild(field.bitmap);
            var data:BitmapData=new BitmapData(960,660,false,0);data.draw(board);png("machines-before",data);
            field.render(loc,view,lights,0.10);
            for(n=0;n<12;n++){var text:TextField=new TextField();text.defaultTextFormat=new TextFormat("Arial",14,0xffffff);text.width=235;text.height=24;text.text=labels[n];text.x=(n%4)*240+5;text.y=int(n/4)*220+8;board.addChild(text);}
            data=new BitmapData(960,660,false,0);data.draw(board);png("machines-after",data);
            check(lights.length==12,"native art gallery contains all supported lit designs");
            field.clear();for each(u in set)drop(u);
        }
        private function finish():void {
            write("loader.json",JSON.stringify(SharedObject.getLocal("ModLoader","/").data,null,2));
            main.stage.removeEventListener(Event.ENTER_FRAME,frame);write("machine-test.log",report+"SUITE_PASS "+mode+" checks="+checks+"\n");
        }
        private function tree(node:DisplayObject,depth:int=0):Object {
            var b:Rectangle=node.getBounds(node),r:Object={name:node.name,type:getQualifiedClassName(node),x:node.x,y:node.y,rotation:node.rotation,visible:node.visible,alpha:node.alpha,bounds:b.toString()};
            if(node is MovieClip){r.frame=MovieClip(node).currentFrame;r.frames=MovieClip(node).totalFrames;}
            if(node is DisplayObjectContainer && depth<4){r.children=[];for(var n:int=0;n<DisplayObjectContainer(node).numChildren;n++)r.children.push(tree(DisplayObjectContainer(node).getChildAt(n),depth+1));}
            return r;
        }
        private function atlas():void {
            var Unit:Class=getDefinitionByName("fe.unit.Unit") as Class,board:Sprite=new Sprite(),metadata:Array=[];
            board.graphics.beginFill(0x30343a);board.graphics.drawRect(0,0,1250,1600);board.graphics.endFill();
            for(var row:int=0;row<names.length;row++)for(var col:int=0;col<5;col++){
                var u:*=Unit["create"](names[row],5,new XML("<u tr='1'/>"),null,names[row]=="ttur"?"1":null);u.putLoc(world.loc,400,600);
                u.animate();u.setVisPos();
                // aiState is internal. Survey the public timeline frames used by native animate().
                if(names[row]=="msp"){u.vis.gotoAndStop(Math.max(1,col));u.vis.osn.gotoAndStop(col<2?"stay":col==3?"walk":"wake");}
                else if(names[row]!="ttur"){u.vis.osn.gotoAndStop(1);u.vis.osn.light.gotoAndStop(col+1);u.vis.osn.puha.rotation=0;}
                if(col==4 && (names[row]=="hturret" || names[row]=="hturret2"))u.vis.osn.gotoAndStop(6);
                metadata.push({kind:names[row],state:col,tree:tree(u.vis)});
                u.vis.x=col*250+125;u.vis.y=row*160+135;u.vis.scaleX=u.vis.scaleY=names[row]=="ttur"?0.55:1.7;board.addChild(u.vis);
                var label:TextField=new TextField();label.defaultTextFormat=new TextFormat("Arial",13,0xffffff);label.width=245;label.height=24;label.text=names[row]+" state="+col;label.x=col*250+5;label.y=row*160+5;board.addChild(label);
            }
            var data:BitmapData=new BitmapData(1250,1600,false,0);data.draw(board);png("native-atlas",data);write("native-tree.json",JSON.stringify(metadata,null,2));
        }
        private function frame(event:Event):void {
            try {
                if(mode=="regression" || mode=="baseline") {
                    var log:File=File.applicationStorageDirectory.resolvePath("test.log");
                    if(log.exists){var stream:FileStream=new FileStream();stream.open(log,FileMode.READ);var output:String=stream.readUTFBytes(stream.bytesAvailable);stream.close();
                        if(output.indexOf(" FAIL ")>=0)throw new Error(output);
                        if(output.indexOf(" SUITE_PASS")>=0){report=output;finish();}}
                    if(getTimer()-started>210000)throw new Error("regression timeout");return;
                }
                var World:Class=getDefinitionByName("fe.World") as Class;world=World["w"];
                if(world && world.verror && world.verror.visible)throw new Error(world.verror.txt.text);
                if(getTimer()-started>120000)throw new Error("timeout phase="+phase);
                if(phase==0 && world && world.allLandsLoaded && world.textLoaded && world.mm){world.mm.mainMenuOff();world.newGame(-1,"LP",{propusk:true});phase=1;}
                else if(phase==1 && world.gg && world.loc && world.loc.active && world.allStat==1){
                    var carrier:*=main.getChildByName("LightAndDarknessCarrier");if(!carrier)return;runtime=carrier.ladAPI.runtime;if(runtime.location!==world.loc || ++frames<6)return;
                    if(mode=="border") {
                        world.gui.dialText(null);world.gui.guiPause=false;world.gui.dialScript.running=false;world.onPause=false;
                        world.pers.healAll();world.pip.noAct=false;world.game.triggers["noreturn"]=0;
                        main.getChildByName("ContinuousSceneCarrier").sceneAPI.travel();phase=10;frames=0;return;
                    }
                    world.onPause=true;if(mode=="atlas")atlas();else verify();phase=2;finished=getTimer();
                } else if(phase==10 && world.land && world.land.act.id=="continuous_scene" && world.allStat==1 && runtime.location===world.loc && ++frames>25) {
                    world.onPause=true;var g:*=world.grafon;
                    report+="BORDER "+[g.ramT.scaleY,g.ramL.scaleX,g.ramB.scaleY,g.ramR.scaleX]+"\n";
                    var before:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);before.draw(main.stage);png("border-before",before.clone());
                    world.cam.setZoom();var after:BitmapData=new BitmapData(before.width,before.height,false,0);after.draw(main.stage);png("border-oracle",after.clone());
                    var difference:*=before.compare(after),changed:int=0;
                    if(difference is BitmapData){for(var y:int=0;y<before.height;y++)for(var x:int=0;x<before.width;x++)if(before.getPixel(x,y)==0 && after.getPixel(x,y)!=0)changed++;difference.dispose();}
                    write("border-result.json",JSON.stringify({beforeScales:report,revealedPixels:changed,version:main.getChildByName("LightAndDarknessCarrier").ladAPI.version},null,2));before.dispose();after.dispose();
                    check(changed==0,"large scene already matches native camera");phase=2;finished=getTimer();
                } else if(phase==2 && getTimer()-finished>11000){finish();
                }
            }catch(e:*){main.stage.removeEventListener(Event.ENTER_FRAME,frame);write("machine-test.log",report+"FAIL "+e+" "+e.getStackTrace());}
        }
    }
}
