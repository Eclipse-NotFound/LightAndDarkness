package {
    import flash.desktop.NativeApplication;
    import flash.display.Sprite;
    import flash.display.BitmapData;
    import flash.display.PNGEncoderOptions;
    import flash.events.Event;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;
    import flash.utils.getTimer;

    /** External driver: all lad/native classes are resolved from the loaded production domain. */
    public class LightAndDarknessProjectileProbe extends Sprite {
        private static var probe:LightAndDarknessProjectileProbe;
        private var main:*,world:*,runtime:*,previousLocation:*;
        private var phase:int=0,ticks:int=0,started:int;
        private var cold:Boolean=false,mode:String="single";
        private var assertions:Array=[];
        private var metrics:Object={};
        private var pausedClock:Number,pausedPower:Number;
        private var gameWasPaused:Boolean=false;
        private var view:Rectangle=new Rectangle(0,0,960,720);
        private var Bullet:Class,Unit:Class,Weapon:Class,Part:Class,Emitter:Class,Projectiles:Class,Field:Class;
        public function LightAndDarknessProjectileProbe() {}
        public static function init(main:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-projectile-")!=0) return;
            probe=new LightAndDarknessProjectileProbe();probe.main=main;probe.started=getTimer();
            var file:File=File.applicationDirectory.resolvePath("projectile-mode.txt");
            if(file.exists) {var input:FileStream=new FileStream();input.open(file,FileMode.READ);probe.mode=input.readUTFBytes(input.bytesAvailable).replace(/\s/g,"");input.close();}
            probe.cold=probe.mode=="cold";
            main.stage.addEventListener(Event.ENTER_FRAME,probe.frame,false,-100);
            probe.log("BOOT "+NativeApplication.nativeApplication.applicationID+" mode="+probe.mode);
        }
        private function cls(name:String):Class {
            var result:Class;
            try {result=getDefinitionByName(name) as Class;}
            catch(error:*) {log("CLASS_RESOLVE_FAILED "+name+" "+error);throw error;}
            return result;
        }
        private function log(text:String):void {
            var output:FileStream=new FileStream();output.open(File.applicationStorageDirectory.resolvePath("projectile-test.log"),FileMode.APPEND);
            output.writeUTFBytes(getTimer()+" "+text+"\n");output.close();
        }
        private function check(ok:Boolean,label:String):void {
            assertions.push({pass:ok,label:label});log((ok?"PASS ":"FAIL ")+label);
            if(!ok) throw new Error(label);
        }
        private function report(status:String,error:String=""):void {
            var passed:int=0;for each(var assertion:Object in assertions) if(assertion.pass) passed++;
            var data:Object={status:status,mode:mode,applicationID:NativeApplication.nativeApplication.applicationID,
                elapsedMs:getTimer()-started,passed:passed,failed:assertions.length-passed,assertions:assertions,
                metrics:metrics,error:error,boundary:"Isolated AIR application; dynamic production classes and real native Bullet/Part/Weapon/Tile. No production or native classes embedded in probe. Synthetic native-object setup is distinguished from live-frame integration."};
            var output:FileStream=new FileStream();output.open(File.applicationStorageDirectory.resolvePath("projectile-report.json"),FileMode.WRITE);
            output.writeUTFBytes(JSON.stringify(data,null,2));output.close();
        }
        private function finish():void {main.stage.removeEventListener(Event.ENTER_FRAME,frame);report("passed");log("SUITE_PASS");}
        private function screenshot(name:String):void {
            var data:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);
            data.draw(main.stage);var output:FileStream=new FileStream();output.open(File.applicationStorageDirectory.resolvePath(name+".png"),FileMode.WRITE);
            output.writeBytes(data.encode(data.rect,new PNGEncoderOptions()));output.close();data.dispose();
        }
        private function resolveClasses():void {
            Bullet=cls("fe.weapon.Bullet");Unit=cls("fe.unit.Unit");Weapon=cls("fe.weapon.Weapon");
            Part=cls("fe.graph.Part");Emitter=cls("fe.graph.Emitter");
            // The manifest loads sibling ApplicationDomains. Native classes are inherited;
            // production classes are obtained from actual installed instances, not reloaded.
            Projectiles=runtime.projectiles.constructor as Class;Field=runtime.field.constructor as Class;
            log("PRODUCTION_CLASSES "+getQualifiedClassName(runtime.projectiles)+" / "+getQualifiedClassName(runtime.field));
        }
        private function tracker():* {var value:*=new Projectiles();value.bind(world,world.loc);return value;}
        private function bullet(visual:String="visualBullet",type:int=0,x:Number=180,y:Number=280,linked:Boolean=false):* {
            var v:Class=visual?cls(visual):null;
            var value:*=new Bullet(world.gg,x,y,v,linked);
            value.tipDamage=type;value.damage=30;value.precision=0;value.miss=0;value.dx=30;value.dy=0;value.vel=30;
            return value;
        }
        private function emit(id:String,x:Number=220,y:Number=280):* {return Emitter["arr"][id].cast(world.loc,x,y,null);}
        private function allLights(value:*,brightness:Number=1):Array {return value.lights(view,brightness);}
        private function classifiedLights(value:*):Array {
            var actual:*=tracker();actual.observe(value);actual.capture();return allLights(actual);
        }
        private function classifiedColour(value:*):Number {
            var emitted:Array=classifiedLights(value);return emitted.length?Number(emitted[0].color):-1;
        }
        private function totalPower(lights:Array):Number {var sum:Number=0;for each(var light:Object in lights) sum+=light.power;return sum;}
        private function remove(value:*):void {if(value && value.in_chain) world.loc.remObj(value);}
        private function cleanChain():void {
            var current:*=world.loc.firstObj,next:*;var count:int=0;
            while(current && count++<10000) {next=current.nobj;current.setNull();if(current.in_chain) world.loc.remObj(current);current=next;}
        }
        private function dismissDialog():void {world.gui.dialText(null);world.gui.guiPause=false;world.gui.dialScript.running=false;}
        private function openPoint():Point {
            var loc:*=world.loc;
            var cx:int=Math.max(2,Math.min(loc.spaceX-3,int(world.gg.X/40)));
            var cy:int=Math.max(2,Math.min(loc.spaceY-3,int((world.gg.Y-world.gg.scY/2)/40)));
            for(var r:int=0;r<7;r++) for(var x:int=Math.max(1,cx-r);x<=Math.min(loc.spaceX-2,cx+r);x++)
                for(var y:int=Math.max(1,cy-r);y<=Math.min(loc.spaceY-2,cy+r);y++)
                    if(Number(loc.space[x][y].opac)<0.99) return new Point(x*40+20,y*40+20);
            throw new Error("no open point in native room");
        }
        private function integrationPulse():void {
            var at:Point=openPoint();var b:*=bullet("visbulplasma",6,at.x,at.y,true);
            b.X+=4;remove(b);runtime.projectiles.capture();runtime.render();
        }
        private function visualCoverage():void {
            var AllData:Class=cls("fe.AllData"),catalog:*=AllData["d"];
            var unique:Object={},ids:Array=[],coverage:Array=[];
            for each(var weaponXml:XML in catalog.weapon) for each(var visualXml:XML in weaponXml.vis) {
                var id:String=String(visualXml.@vbul);
                if(id.length && !unique[id]) {unique[id]=true;ids.push(id);}
            }
            ids.sort();metrics.visualCoverage=coverage;metrics.visualCount=ids.length;
            check(ids.length==68,"native AllData enumerates all 68 distinct projectile visual identifiers including variants");
            var dark:String=",dart,saw,spikenail,ship,venom,plevok,pinkplevok,kapl,pinkkapl,pink,gren40,gren50,";
            for each(id in ids) {
                var row:Object={visual:id,nativeClass:"visbul"+id,expectedLit:dark.indexOf(","+id+",")<0};coverage.push(row);
                var actual:*=bullet("visbul"+id,0,180,280);actual.spring=2;
                var emitted:Array=classifiedLights(actual);row.actualLit=emitted.length>0;row.lightCount=emitted.length;
                row.colour=emitted.length?uint(emitted[0].color).toString(16):null;
                check(row.actualLit==row.expectedLit,"native visual coverage "+id+" "+(row.expectedLit?"illuminates":"stays dark in flight"));
            }
        }

        /** One synchronous paused transaction, restored even if an assertion fails. */
        private function nativeChecks():void {
            var loc:*=world.loc;
            var saved:Object={space:loc.space,spaceX:loc.spaceX,spaceY:loc.spaceY,limX:loc.limX,limY:loc.limY,
                units:loc.units,firstObj:loc.firstObj,lastObj:loc.lastObj,nextObj:loc.nextObj,sky:loc.sky,
                celObj:loc.celObj,isRebuild:loc.isRebuild,isRelight:loc.isRelight,warning:loc.warning};
            var oldPause:Boolean=world.onPause,oldTestDam:Boolean=world.testDam;
            var field:*=new Field(),local:*;
            var Tile:Class=cls("fe.loc.Tile");
            try {
                world.onPause=true;loc.space=[];loc.spaceX=24;loc.spaceY=18;loc.limX=960;loc.limY=720;
                loc.units=[];loc.firstObj=null;loc.lastObj=null;loc.nextObj=null;loc.sky=false;loc.celObj=null;
                for(var tx:int=0;tx<24;tx++) {loc.space[tx]=[];for(var ty:int=0;ty<18;ty++) {
                    var tile:*=new Tile(tx,ty);tile.opac=tx==10?1:0;tile.phis=tx==10?1:0;tile.mat=2;tile.indestruct=true;loc.space[tx][ty]=tile;
                }}
                runtime.projectiles.clear();runtime.projectiles.bind(world,loc);
                visualCoverage();
                check(classifiedLights({loc:loc,vis:new Sprite(),tipDamage:6,X:180,Y:280}).length==0,"plain Object cannot impersonate native projectile");
                var b:*=bullet();
                check(classifiedColour(b)==0xFFE3AA,"real native ballistic bullet receives warm short tracer profile");
                var owner:*=new Unit();owner.loc=loc;owner.setPos(180,300);owner.fraction=2;owner.weaponX=180;owner.weaponY=280;owner.celX=360;owner.celY=280;
                var weapon:*=new Weapon(owner,"p10mm");weapon.ammoFire=1;b.weap=weapon;
                check(classifiedColour(b)==0xFFD08B,"real native Weapon incendiary ammo overrides unchanged ballistic damage type");
                b.tipDamage=6;check(classifiedColour(b)==0xA0FF9C,"live plasma ammo modification wins over ballistic visual");
                b.tipDamage=8;check(classifiedColour(b)==0x9DE6FF,"live EMP ammo receives electric light profile");
                b=bullet("visbullaser",5);b.spring=2;b.X=360;
                check(classifiedColour(b)==0xFF9A88 && classifiedLights(b).length>=3,"native laser visual with spring stretch receives beam profile");
                b=bullet("visualBullet",0);b.spring=3;
                check(classifiedColour(b)==0xFFE3AA,"spring stretch alone does not classify ballistic shot as beam");
                var Phis:Class=cls("fe.weapon.PhisBullet");var grenade:*=new Phis(world.gg,180,280,cls("visbulgren40"));
                grenade.tipDamage=4;grenade.explRadius=100;
                check(classifiedLights(grenade).length==0,"native physical grenade stays unlit before detonation");
                local=tracker();local.observe(grenade);local.capture();check(allLights(local).length==0,"unlit physical grenade produces no flight illumination");remove(grenade);
                b=bullet(null,4);b.damageExpl=0;b.liv=3;
                check(classifiedLights(b).length==0,"invisible native blast-delivery bullet is excluded");
                b=bullet("visualBullet",0);b.tipBullet=1;
                check(classifiedLights(b).length==0,"melee sweep marker is excluded even if a visual is attached");
                b=bullet("visbulvenom",7);check(classifiedLights(b).length==0,"physical venom projectile stays dark");
                b=bullet("visbulplasma",6);
                check(classifiedColour(b)==0xACFFA2,"native energy projectile receives plasma profile");
                var Smart:Class=cls("fe.weapon.SmartBullet");var smart:*=new Smart(world.gg,180,280,cls("visbulrocket"));smart.tipDamage=4;
                check(classifiedColour(smart)==0xFFB06B,"native SmartBullet is classified without replacing guidance");remove(smart);

                // The native constructor dispatches ADDED before these final fields are assigned.
                runtime.projectiles.clear();runtime.projectiles.bind(world,loc);
                var before:int=runtime.projectiles.captured;
                b=bullet("visualBullet",6,180,280,true);
                check(runtime.projectiles.captured==before+1,"actual native addObj ADDED enters production runtime observer");
                b.liv=1;b.dx=100;b.vel=100;var originalDamage:Number=b.damage;
                b.step();check(!b.in_chain,"native lifetime ends in same frame as constructor event");
                runtime.projectiles.capture();var live:Array=allLights(runtime.projectiles);
                check(live.length>0 && live[0].color==0xA0FF9C,"same-frame removed bullet retains final ammo classification and short light");
                check(b.damage==originalDamage && b.liv==0 && !b.in_chain,"capture does not revive or alter native removed bullet damage or lifetime");

                local=tracker();b=bullet("visualBullet",0,180,280,true);local.observe(b);var originalLiv:int=b.liv;
                local.capture();var pulseCount:int=local.pulseCount;
                local.observe(b);local.capture();
                check(local.pulseCount==pulseCount && b.damage==30 && b.liv==originalLiv && b.in_chain,"duplicate observe and capture neither duplicate light nor mutate live bullet");
                b.remVisual();b.addVisual();runtime.projectiles.capture();
                check(b.in_chain && b.liv==originalLiv,"native display remount leaves projectile gameplay intact");remove(b);

                local=tracker();b=bullet("visbulplasma",6,220,280);local.observe(b);local.capture();live=allLights(local);
                field.render(loc,view,live,0.05);var lit:Number=field.sample(220,280);
                var px:int=int((220-field.bounds.x)/12),py:int=int((280-field.bounds.y)/12),color:uint=field.data.getPixel(px,py);
                check(lit>0.2 && ((color>>8)&255)>(color&255),"real plasma profile brightens shared raster with a green tint");
                var fullPower:Number=totalPower(live),halfPower:Number=totalPower(allLights(local,0.5));
                check(Math.abs(halfPower-fullPower/2)<0.0001,"projectile brightness scales existing light rather than extending lifetime");
                local.advance();var decayed:Number=totalPower(allLights(local));
                check(decayed>0 && decayed<fullPower,"detached projectile light decays on native-rate simulation advance");
                for(var age:int=0;age<30;age++) local.advance();
                check(allLights(local).length==0 && local.pulseCount==0,"detached projectile afterglow expires without retained pulse");

                local=tracker();b=bullet("visualBullet",0,380,280,true);b.dx=30;b.vel=30;b.partEmit=false;local.observe(b);b.step();
                check(b.tilehit && b.babah && b.X>=400,"native collision endpoint really enters opaque wall tile");local.capture();live=allLights(local);
                var foundImpact:Boolean=false,allFree:Boolean=true;
                for each(var light:Object in live) {if(String(light.id).indexOf("impact:")>=0) foundImpact=true;if(light.x>=400 && light.x<440) allFree=false;}
                check(foundImpact && allFree,"wall impact light retreats to free side of native collision wall");
                field.render(loc,view,live,0.05);
                check(field.sample(385,280)>0.1 && field.sample(460,280)<0.09,"projectile light illuminates near wall while opaque wall shields far side");remove(b);

                local=tracker();b=bullet("visbullaser",5,120,200);b.spring=2;local.observe(b);b.X=360;local.capture();live=allLights(local);
                var minimum:Number=9999,maximum:Number=-9999;
                for each(light in live) if(String(light.id).indexOf("trail:")>=0) {minimum=Math.min(minimum,light.x);maximum=Math.max(maximum,light.x);}
                check(maximum-minimum>100 && minimum>=120 && maximum<=360,"beam light nodes follow actual native start and endpoint");

                // Rendering an already-resolved long native beam must concentrate its bounded
                // nodes around the current viewport instead of spacing them across the whole map.
                for(ty=0;ty<18;ty++) loc.space[10][ty].opac=0;
                var beamView:Rectangle=new Rectangle(120,80,600,220);local=tracker();local.setView(beamView);
                b=bullet("visbullaser",5,-3000,160);b.spring=2;local.observe(b);b.X=5000;local.capture();live=local.lights(beamView);
                field.render(loc,beamView,live,0.05);var continuous:Boolean=true;
                for(var sampleX:int=160;sampleX<=680;sampleX+=40) if(field.sample(sampleX,160)<0.15) continuous=false;
                check(continuous && live.length<=24,"long resolved native beam keeps continuous bounded illumination across current viewport");
                for(ty=0;ty<18;ty++) loc.space[10][ty].opac=1;

                local=tracker();var part:*=emit("expl",240,350);local.observe(part);local.capture();
                check(getQualifiedClassName(part)=="fe.graph::Part" && part.blitData!=null && allLights(local).length>0,"native blit explosion Part is recognized by production resource identity");
                local=tracker();part=emit("plaexpl",240,350);local.observe(part);local.capture();
                check(part.vClass!=null && allLights(local).length>0 && allLights(local)[0].color==0xACFFA2,"native MovieClip explosion Part receives plasma colour");
                local=tracker();part=emit("gilza",240,350);local.observe(part);local.capture();
                check(allLights(local).length==0,"native ejected shell Part is not a light source");
                local=tracker();part=emit("gas",240,350);local.observe(part);local.capture();
                check(allLights(local).length==0,"native poison cloud does not become a room lamp");

                local=tracker();part=emit("fireexpl",240,350);local.observe(part);local.capture();
                check(allLights(local).length>0 && allLights(local)[0].color==0xFFC078,"shared explosion bitmap keeps native fire blend colour classification");
                local=tracker();part=emit("ttexpl",240,350);local.observe(part);local.capture();
                check(allLights(local).length>0 && allLights(local)[0].radius>=300,"shared explosion bitmap keeps large native blast scale");
                local=tracker();var special:*=Weapon["create"](owner,"spgren");
                b=bullet("visbulgren40",4,240,350);b.weap=special;b.explRadius=160;b.damageExpl=0;
                check(classifiedLights(b).length==0,"native sparkle grenade alias has no light before detonation");
                local.observe(b);b.explosion();local.capture();
                check(allLights(local).length>0 && allLights(local)[0].color==0xE0B5FF,"native sparkle grenade alias selects violet detonation");
                // Observe generic and special native particles in both addition orders.
                part=emit("sparkleexpl",240,350);local.observe(part);part=emit("expl",240,350);local.observe(part);local.capture();
                check(allLights(local).length==1 && allLights(local)[0].color==0xE0B5FF,"generic and sparkle explosion cluster keeps strongest special colour without duplicate light");

                runtime.projectiles.clear();runtime.projectiles.bind(world,loc);
                var direct:*=new Bullet(world.gg,240,350,null,false);direct.iExpl(0,0,100);runtime.projectiles.capture();
                check(!direct.in_chain && direct.vis==null && allLights(runtime.projectiles).length>0,"direct invisible unlinked native explosion is detected through actual ADDED particles");
                var oneExplosionCount:int=runtime.projectiles.pulseCount;
                runtime.projectiles.capture();check(runtime.projectiles.pulseCount==oneExplosionCount,"repeated capture cannot replay native explosion particles");
                check(oneExplosionCount<=4,"one native explosion and its particle cluster do not create unbounded lights");

                // Fire a real throwaway weapon via native public attack/actions, not protected shoot.
                cleanChain();runtime.projectiles.clear();runtime.projectiles.bind(world,loc);
                weapon=new Weapon(owner,"p10mm");weapon.X=180;weapon.Y=280;weapon.findCel=false;weapon.hold=50;
                weapon.hp=weapon.maxhp;weapon.t_attack=0;weapon.t_reload=0;weapon.t_auto=0;
                var accepted:Boolean=weapon.attack();weapon.actions();var fired:*=weapon.b;
                check(accepted && fired && fired.in_chain && fired.weap===weapon,"native Weapon attack/actions creates genuine projectile");
                runtime.projectiles.capture();check(allLights(runtime.projectiles).length>0,"real native weapon firing reaches production illumination");
                var target:*=new Unit();target.loc=loc;target.fraction=3;target.hp=target.maxhp=1000;target.dexter=0;target.skin=0;target.armor=0;
                target.setPos(fired.X+10,fired.Y+10);target.scX=60;target.scY=60;target.setPos(fired.X+10,fired.Y+30);target.fixed=true;
                loc.units=[target];fired.precision=0;fired.miss=0;fired.critCh=0;fired.dx=10;fired.dy=0;fired.vel=10;fired.knockx=0;fired.knocky=0;
                var hp:Number=target.hp;fired.run();runtime.projectiles.capture();
                check(target.hp<hp,"real illuminated native projectile still deals native collision damage");loc.units=[];cleanChain();

                local=tracker();var stressStart:int=getTimer();
                for(var index:int=0;index<230;index++) {b=bullet("visualBullet",0,80+(index%8)*35,80+int(index/8)*16);local.observe(b);}
                check(local.trackedCount<=192 && local.dropped>0,"dense projectile observer obeys explicit tracked-object cap");local.capture();
                check(local.pulseCount<=96 && allLights(local).length<=24,"dense short-light batch obeys pulse and render caps");
                metrics.stressCaptureMs=getTimer()-stressStart;metrics.stressPulseCount=local.pulseCount;metrics.stressVisibleCount=allLights(local).length;
                var far:Rectangle=new Rectangle(9000,9000,500,300);check(local.lights(far).length==0,"offscreen projectile lights are culled from render list");
                var renderStart:int=getTimer();field.render(loc,view,allLights(local),0.05);metrics.stressRenderMs=getTimer()-renderStart;
                check(isFinite(metrics.stressRenderMs) && metrics.stressRenderMs<2000,"bounded projectile stress raster completes without runaway frame");
                local.bind(world,null);check(local.trackedCount==0 && local.pulseCount==0 && local.clock==0,"location unload discards every transient reference and simulation clock");
            } finally {
                cleanChain();field.clear();runtime.projectiles.clear();
                for(var key:String in saved) loc[key]=saved[key];
                world.testDam=oldTestDam;world.onPause=oldPause;runtime.projectiles.bind(world,loc);
            }
        }

        private function frame(event:Event):void {
            try {
                var World:Class=cls("fe.World");world=World["w"];
                if(world && world.verror && world.verror.visible) throw new Error("HOST_ERROR "+world.verror.txt.text);
                if(getTimer()-started>175000) throw new Error("TIMEOUT phase="+phase);
                if(phase==0 && world && world.allLandsLoaded && world.textLoaded && world.mm) {
                    world.mm.mainMenuOff();world.newGame(cold?7:-1,"LP",{propusk:true});phase=1;
                } else if(phase==1 && world.gg && world.loc && world.loc.active && world.allStat==1) {
                    var carrier:*=main.getChildByName("LightAndDarknessCarrier");if(!carrier) return;
                    runtime=carrier.ladAPI.runtime;if(runtime.location!==world.loc) return;
                    resolveClasses();dismissDialog();phase=2;ticks=0;
                } else if(phase==2 && ++ticks>24) {
                    dismissDialog();check(runtime.projectiles!=null,"production runtime exposes projectile service");
                    if(cold) {
                        check(!runtime.atmosphere.settings.projectiles,"cold native slot restores disabled projectile preference");
                        check(Math.abs(runtime.atmosphere.settings.projectileBrightness-0.65)<0.001,"cold native slot restores projectile brightness preference");
                        check(runtime.projectiles.pulseCount==0 && runtime.projectiles.trackedCount==0,"cold load never resurrects saved projectile lights");finish();return;
                    }
                    runtime.setAtmospherePreference("projectiles",true);runtime.setAtmospherePreference("projectileBrightness",1);
                    nativeChecks();dismissDialog();gameWasPaused=world.onPause;world.onPause=true;
                    runtime.render();screenshot("projectile-before");
                    integrationPulse();pausedClock=runtime.projectiles.clock;
                    pausedPower=totalPower(runtime.projectiles.lights(new Rectangle(0,0,world.loc.limX,world.loc.limY)));
                    check(pausedPower>0,"real runtime retains generated short light for pause integration check");
                    screenshot("projectile-lit-paused");phase=3;ticks=0;
                } else if(phase==3 && ++ticks>=12) {
                    check(runtime.projectiles.clock==pausedClock,"twelve real paused frames do not advance projectile simulation age");
                    var currentPower:Number=totalPower(runtime.projectiles.lights(new Rectangle(0,0,world.loc.limX,world.loc.limY)));
                    check(Math.abs(currentPower-pausedPower)<0.0001,"paused frames preserve short-light fade without wall-clock expiry");
                    world.onPause=false;phase=4;ticks=0;
                } else if(phase==4 && ++ticks>=10) {
                    check(runtime.projectiles.clock>pausedClock,"native player simulation hook resumes projectile clock");
                    check(totalPower(runtime.projectiles.lights(new Rectangle(0,0,world.loc.limX,world.loc.limY)))<pausedPower,"real resumed frames fade short light rather than freezing it into scene");
                    runtime.render();screenshot("projectile-after");
                    world.onPause=true;integrationPulse();runtime.setAtmospherePreference("projectiles",false);
                    check(runtime.projectiles.trackedCount==0 && runtime.projectiles.pulseCount==0,"projectile setting off immediately clears transient state");
                    runtime.setAtmospherePreference("projectiles",true);integrationPulse();runtime.setEnabled(false);
                    check(runtime.projectiles.trackedCount==0 && runtime.projectiles.pulseCount==0,"whole-mod disable clears transient light and references");
                    runtime.setEnabled(true);world.onPause=false;phase=5;ticks=0;
                } else if(phase==5 && runtime.location===world.loc && ++ticks>=4) {
                    dismissDialog();runtime.setAtmospherePreference("projectiles",false);runtime.setAtmospherePreference("projectileBrightness",0.65);
                    world.pip.noAct=false;world.saveGame(7);
                    check(world.getSave(7)!=null && world.getSave(7).game!=null,"native test slot exists and save completes");
                    var encoded:*=world.getSave(7).game.triggers["lightanddarkness.state.v1"];
                    check(encoded is String && encoded.indexOf('"projectiles":false')>=0,"native save stores projectile opt-out with ordinary light preferences");
                    check(encoded.indexOf("trackedCount")<0 && encoded.indexOf('"pulses"')<0,"native save omits transient projectile state");
                    previousLocation=world.loc;world.comLoad=7;phase=6;ticks=0;
                } else if(phase==6 && world.loc && world.loc!==previousLocation && runtime.location===world.loc && world.allStat==1) {
                    dismissDialog();check(!runtime.atmosphere.settings.projectiles && Math.abs(runtime.atmosphere.settings.projectileBrightness-0.65)<0.001,"actual native reload restores projectile settings on new Location");
                    check(runtime.projectiles.pulseCount==0 && runtime.projectiles.trackedCount==0,"actual native room replacement has no previous-scene projectile light");
                    world.onPause=gameWasPaused;metrics.preparedScenes=runtime.preparedScenes;metrics.fixtureCount=runtime.lamps.length;
                    finish();
                }
            } catch(error:*) {
                main.stage.removeEventListener(Event.ENTER_FRAME,frame);
                var detail:String=String(error)+" "+error.getStackTrace();log("FAIL "+detail);report("failed",detail);
            }
        }
    }
}
