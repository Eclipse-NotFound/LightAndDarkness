package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.Event;
    import flash.filesystem.*;
    import flash.geom.*;
    import flash.net.*;
    import flash.system.*;
    import flash.text.*;
    import flash.utils.*;
    /** Native art inventory, production-byte regression and paired raster timings. */
    public class TrailProbeMod extends Sprite {
        public function TrailProbeMod() {}
        private static var self:TrailProbeMod;
        private var main:*,w:*,r:*,mode:String,phase:int=0,age:int=0,started:int,checks:int=0;
        private var reference:Loader=new Loader(),domain:ApplicationDomain,rows:Array=[];
        private var view:Rectangle=new Rectangle(0,0,960,720);
        public static function init(root:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-projectile-trails-")!=0)return;
            self=new TrailProbeMod();self.main=root;self.started=getTimer();
            var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("trail-mode.txt"),FileMode.READ);self.mode=f.readUTFBytes(f.bytesAvailable);f.close();
            if(self.mode=="legacy" || self.mode=="cold")LightAndDarknessProjectileProbe.init(root);
            self.reference.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {self.domain=self.reference.contentLoaderInfo.applicationDomain;});
            self.reference.load(new URLRequest(File.applicationDirectory.resolvePath("baseline.swf").url),new LoaderContext(false,new ApplicationDomain(root.loaderInfo.applicationDomain)));
            root.stage.addEventListener(Event.ENTER_FRAME,self.step,false,-150);
        }
        private function write(name:String,text:String):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);f.writeUTFBytes(text);f.close();}
        private function png(name:String,b:BitmapData):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);f.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));f.close();b.dispose();}
        private function check(ok:Boolean,label:String):void {if(!ok)throw new Error(label);checks++;var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("checks.log"),FileMode.APPEND);f.writeUTFBytes("PASS "+label+"\n");f.close();}
        private function finish(error:String=""):void {
            main.stage.removeEventListener(Event.ENTER_FRAME,step);
            write("trail.json",JSON.stringify({error:error,mode:mode,version:r?main.getChildByName("LightAndDarknessCarrier").ladAPI.version:"",roomsLoad:w?w.roomsLoad:0,checks:checks,samples:rows,loader:SharedObject.getLocal("ModLoader","/").data},null,2));
            write("trail.done",error?"FAIL "+error:"PASS");NativeApplication.nativeApplication.exit(error?1:0);
        }
        private function atlas():void {
            var ids:Array=["visualBullet","visualRainbow"],seen:Object={},xml:*=getDefinitionByName("fe.AllData")["d"];
            for each(var weapon:XML in xml.weapon)for each(var vis:XML in weapon.vis){var id:String=String(vis.@vbul);if(id && !seen[id]){seen[id]=true;ids.push("visbul"+id);}}
            ids.sort();check(ids.length==70,"all 68 XML visuals plus ordinary and rainbow art");
            var board:Sprite,data:Array=[];
            for(var i:int=0;i<ids.length;++i) {
                if(i%20==0){board=new Sprite();board.graphics.beginFill(0x252b32);board.graphics.drawRect(0,0,1200,600);board.graphics.endFill();}
                var C:Class=getDefinitionByName(ids[i]) as Class,v:MovieClip=new C(),b:Rectangle=v.getBounds(v);
                var row:Object={id:ids[i],frames:v.totalFrames,bounds:{x:b.x,y:b.y,width:b.width,height:b.height},laser:("laser" in v) && v["laser"]!=null};data.push(row);
                var col:int=i%4,line:int=int((i%20)/4),label:TextField=new TextField();label.defaultTextFormat=new TextFormat("Arial",13,0xffffff);label.width=295;label.text=ids[i]+" / "+v.totalFrames+"f";label.x=col*300+5;label.y=line*120+5;board.addChild(label);
                for(var sample:int=0;sample<2;sample++) {
                    var frame:int=sample==0?1:Math.max(1,Math.min(6,v.totalFrames));v.gotoAndStop(frame);b=v.getBounds(v);
                    var scale:Number=Math.min(1,270/Math.max(1,b.width),42/Math.max(1,b.height));
                    var image:BitmapData=new BitmapData(292,44,true,0);image.draw(v,new Matrix(scale,0,0,scale,10-b.x*scale,22-(b.y+b.height/2)*scale));
                    var bm:Bitmap=new Bitmap(image);bm.x=col*300+3;bm.y=line*120+26+sample*44;board.addChild(bm);
                    if(sample==1)row.frame6Bounds={x:b.x,y:b.y,width:b.width,height:b.height};
                }
                if(i%20==19 || i==ids.length-1){var out:BitmapData=new BitmapData(1200,600,false,0);out.draw(board);png("native-projectiles-"+int(i/20),out);}
            }
            write("native-shapes.json",JSON.stringify(data,null,2));
        }
        private function makeBullet(visual:String,x:Number,y:Number,linked:Boolean=true):* {
            var B:Class=getDefinitionByName("fe.weapon.Bullet") as Class,V:Class=getDefinitionByName(visual) as Class;
            var b:*=new B(w.gg,x,y,V,linked);b.tipDamage=0;b.dx=60;b.dy=0;b.vel=60;b.damage=30;b.partEmit=false;b.liv=1000;
            if(visual.indexOf("visbullaser")==0)b.spring=2;
            return b;
        }
        private function clean():void {var b:*=w.loc.firstObj,n:*;while(b){n=b.nobj;b.setNull();if(b.in_chain)w.loc.remObj(b);b=n;}}
        private function trails(lights:Array):Array {var out:Array=[];for each(var light:Object in lights)if(light.trail)out.push(light);return out;}
        private function stats(values:Array):Object {var a:Array=values.concat();a.sort(Array.NUMERIC);var sum:Number=0;for each(var v:Number in a)sum+=v;return {mean:sum/a.length,p50:a[int(a.length*.5)],p95:a[Math.min(a.length-1,int(a.length*.95))],max:a[a.length-1],raw:values};}
        private function nativeWork():void {
            var loc:*=w.loc,saved:Object={space:loc.space,spaceX:loc.spaceX,spaceY:loc.spaceY,limX:loc.limX,limY:loc.limY,firstObj:loc.firstObj,lastObj:loc.lastObj,nextObj:loc.nextObj,units:loc.units,sky:loc.sky};
            var Tile:Class=getDefinitionByName("fe.loc.Tile") as Class,P:Class=r.projectiles.constructor as Class,F:Class=r.field.constructor as Class;
            var f:*=new F(),p:*=new P();
            try {
                loc.space=[];loc.spaceX=48;loc.spaceY=25;loc.limX=1920;loc.limY=1000;loc.firstObj=loc.lastObj=loc.nextObj=null;loc.units=[];loc.sky=false;
                for(var x:int=0;x<48;++x){loc.space[x]=[];for(var y:int=0;y<25;++y){var tile:*=new Tile(x,y);tile.opac=0;tile.phis=0;loc.space[x][y]=tile;}}
                if(mode=="perf"){benchmark(P,F);return;}
                p.bind(w,loc);p.setView(view);
                var b:*=makeBullet("visualBullet",140,280);p.observe(b);b.X=300;p.capture();
                var a:Array=trails(p.lights(view));check(a.length==1,"one moving bullet produces one ribbon, not multiple radial nodes");
                var s:Object=a[0].trail[0];check(s.bx>s.ax && s.by==s.ay && s.bx-s.ax<=89,"ordinary native slow tracer keeps bounded horizontal history");
                check(s.head>s.tail && s.width<=34,"ordinary trail has a dimmer narrow tail");
                f.render(loc,view,a,.05);check(f.sample(270,280)>f.sample(270,328)+.12,"light spills along trajectory and is narrow across trajectory");
                check(f.sample(265,280)>f.sample(218,280),"head of the ribbon is brighter than the older tail");
                var image:BitmapData=f.data.clone();png("ribbon-horizontal",image);
                p.clear();p.bind(w,loc);p.setView(view);clean();b=makeBullet("visualBullet",300,100);p.observe(b);b.Y=300;p.capture();a=trails(p.lights(view));f.render(loc,view,a,.05);
                check(f.sample(300,270)>f.sample(348,270)+.12,"vertical shot rotates the spill without a horizontal bias");
                p.clear();p.bind(w,loc);p.setView(view);clean();b=makeBullet("visbulrocket",160,200);p.observe(b);b.X=200;p.capture();b.X=230;b.Y=230;p.capture();a=trails(p.lights(view));
                check(a.length==1 && a[0].trail.length>=2,"turning rocket retains a bent path");
                s=a[0].trail[0];check(s.bx<230 && s.by<230,"rocket illumination starts behind the missile body");
                p.clear();p.bind(w,loc);p.setView(view);clean();b=makeBullet("visbullaser",100,360);p.observe(b);b.X=900;p.capture();a=trails(p.lights(view));
                check(a.length==1 && a[0].trail[0].ax==100 && a[0].trail[0].bx==900,"native beam uses exact start and collision endpoint");
                f.render(loc,view,a,.05);var continuous:Boolean=true;for(x=120;x<880;x+=12)if(f.sample(x,360)<.3)continuous=false;check(continuous,"beam illumination is continuous between former circle sample points");
                png("ribbon-beam",f.data.clone());
                for(y=0;y<25;y++)loc.space[10][y].opac=1;
                p.clear();p.bind(w,loc);p.setView(view);clean();b=makeBullet("visbullaser",100,360);p.observe(b);b.X=420;p.capture();a=trails(p.lights(view));f.render(loc,view,a,.05);
                check(f.sample(380,360)>.1 && f.sample(460,360)<.06,"native beam endpoint inside wall cannot light the far side");
                // Adjacent parallel trail must also respect the wall sideways.
                p.clear();p.bind(w,loc);p.setView(view);clean();b=makeBullet("visbulplasma",375,150);p.observe(b);b.Y=400;p.capture();a=trails(p.lights(view));f.render(loc,view,a,.05);
                check(f.sample(370,380)>.12 && f.sample(450,380)<.06,"wide energy ribbon is occluded sideways by solid wall");
                for(y=0;y<25;y++)loc.space[10][y].opac=0;
                f.render(loc,view,a,.05);check(f.sample(420,380)>.06,"removing an opaque tile immediately exposes the ribbon spill");
                var same:Array=a.concat(a,a,a,a,a);f.render(loc,view,a,.05);var before:BitmapData=f.data.clone();f.render(loc,view,same,.05);var diff:*=before.compare(f.data);check(diff===0,"overlapping identical ribbons do not brighten without bound");if(diff is BitmapData)diff.dispose();before.dispose();
                var fresh:*=new F(),small:Rectangle=new Rectangle(60,120,600,420);
                f.render(loc,small,a,.05);fresh.render(loc,small,a,.05);diff=f.data.compare(fresh.data);check(diff===0,"resized reused raster matches a fresh raster");if(diff is BitmapData)diff.dispose();
                f.render(loc,view,a,.05);fresh.clear();fresh.render(loc,view,a,.05);diff=f.data.compare(fresh.data);check(diff===0,"restoring a larger viewport has no stale trail pixels");if(diff is BitmapData)diff.dispose();fresh.clear();
                for each(var v:String in ["visbulplasma","visbulflame","visbulice","visbulblump","visbulbaleegg","visbuleclipse","visbulskybolt","visbulblood","visbulnecro","visbulplasma2","visbulplasma5","visbulttnavod","visbulgren50"]){
                    p.clear();p.bind(w,loc);p.setView(view);clean();b=makeBullet(v,140,220);p.observe(b);b.X=330;p.capture();a=trails(p.lights(view));check(a.length>0,"native shape has directional spill "+v);
                }
                p.clear();p.bind(w,loc);p.setView(view);clean();
                var PB:Class=getDefinitionByName("fe.weapon.PhisBullet") as Class,GV:Class=getDefinitionByName("visbulgren50") as Class;
                b=new PB(w.gg,140,220,GV);b.tipDamage=4;p.observe(b);b.X=260;p.capture();
                check(trails(p.lights(view)).length==1,"actual PhisBullet gren50 spell emits while ordinary grenade shells stay dark");
                clean();p.clear();p.bind(w,loc);p.setView(view);
                for(var i:int=0;i<230;++i){b=makeBullet("visualBullet",80+(i%16)*40,80+int(i/16)*32);p.observe(b);b.X+=90;}
                p.capture();a=p.lights(view);f.render(loc,view,a,.05);check(p.trackedCount<=192 && p.pulseCount<=96 && a.length<=24,"230 native bullets respect all three collection budgets");
                check(f.trailRaster.visits<=65536 && !f.trailRaster.limited,"dense ordinary barrage stays below raster work ceiling");
                rows.push({stress:{tracked:p.trackedCount,pulses:p.pulseCount,lights:a.length,visits:f.trailRaster.visits,rays:f.trailRaster.rays,painted:f.trailRaster.painted}});
                clean();for(i=0;i<30;i++)p.advance();check(p.lights(view).length==0,"detached trails and flashes expire on simulation steps");
                f.render(loc,view,[],.05);check(f.sample(300,280)<.06,"last trail leaves no retained pixels after expiry");
            } finally {clean();f.clear();p.clear();r.projectiles.clear();for(var key:String in saved)loc[key]=saved[key];r.projectiles.bind(w,loc);}
        }
        private function benchmark(P:Class,F:Class):void {
            var OP:Class=domain.getDefinition("lad.LadProjectiles") as Class,OF:Class=domain.getDefinition("lad.LadLightField") as Class;
            for each(var kind:String in ["rifle-24","shotgun-192","plasma-96","beam-24"]) {
                var count:int=int(kind.split("-")[1]),visual:String=kind.indexOf("plasma")==0?"visbulplasma":kind.indexOf("beam")==0?"visbullaser":"visualBullet";
                for(var round:int=0;round<4;++round) {
                    var candidate:Boolean=round==1 || round==2,PC:Class=candidate?P:OP,FC:Class=candidate?F:OF;
                    var p:*=new PC(),f:*=new FC();p.bind(w,w.loc);p.setView(view);var bullets:Array=[];clean();
                    for(var i:int=0;i<count;++i){var b:*=makeBullet(visual,90+(i%12)*55,100+int(i/12)*28);bullets.push(b);p.observe(b);}
                    var collect:Array=[],render:Array=[],combined:Array=[],maxLights:int=0,visits:int=0,rebuilds:int=0;
                    // 20 warmup frames, then 80 actual samples, same positions and order.
                    for(var tick:int=0;tick<100;++tick) {
                        for(i=0;i<count;i++){b=bullets[i];b.X=130+((tick*37+i*51)%660);b.Y=100+int(i/12)*28+(i%3)*4;}
                        var t:int=getTimer();p.advance();var a:Array=p.lights(view),mid:int=getTimer();f.render(w.loc,view,a,.05);var end:int=getTimer();
                        if(tick>=20){collect.push(mid-t);render.push(end-mid);combined.push(end-t);maxLights=Math.max(maxLights,a.length);if(candidate)visits=Math.max(visits,f.trailRaster.visits);}
                    }
                    rows.push({kind:kind,round:round,candidate:candidate,collect:stats(collect),render:stats(render),combined:stats(combined),maxLights:maxLights,maxVisits:visits,rebuilds:f.rebuilds});
                    f.clear();p.clear();clean();
                }
            }
        }
        private function step(e:Event):void {
            try {
                w=getDefinitionByName("fe.World")["w"];
                if(w && w.verror && w.verror.visible)throw new Error(w.verror.txt.text);
                var carrier:*=main.getChildByName("LightAndDarknessCarrier");if(carrier)r=carrier.ladAPI.runtime;
                if(getTimer()-started>360000)throw new Error("timeout");
                if(mode=="legacy" || mode=="cold") {
                    var file:File=File.applicationStorageDirectory.resolvePath("projectile-report.json");if(!file.exists)return;
                    var input:FileStream=new FileStream();input.open(file,FileMode.READ);var result:Object=JSON.parse(input.readUTFBytes(input.bytesAvailable));input.close();if(result.status!="passed")throw new Error(result.error);checks=result.passed;rows.push(result.metrics);finish();return;
                }
                if(phase==0 && domain && w && w.allLandsLoaded && w.textLoaded && w.mm){w.mm.mainMenuOff();w.newGame(-1,"LP",{propusk:true});phase=1;}
                else if(phase==1 && r && w.gg && w.loc && w.loc.active && w.allStat==1 && w.t_exit==0 && r.location===w.loc && ++age>15){
                    w.gui.dialText(null);w.gui.guiPause=false;w.gui.dialScript.running=false;w.onPause=true;r.enabled=false;
                    if(mode=="atlas")atlas();else {nativeWork();if(mode=="verify")atlas();}finish();
                }
            }catch(error:*){finish(String(error)+" "+error.getStackTrace());}
        }
    }
}
