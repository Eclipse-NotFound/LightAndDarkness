package {
    import flash.display.*;
    import flash.geom.*;
    import flash.text.*;
    import flash.utils.getDefinitionByName;
    public final class LandmarkChecks {
        public static function run(w:*,r:*,main:*,check:Function,png:Function):void {
            var CP:Class=getDefinitionByName("fe.loc.CheckPoint") as Class,Box:Class=getDefinitionByName("fe.loc.Box") as Class;
            var layer:Sprite=new Sprite(),view:Rectangle=new Rectangle(0,0,1200,800),objs:Array=[];
            function collect(list:Array,rect:Rectangle=null):Array {
                var oldActs:Array=w.loc.acts,oldObjs:Array=w.loc.objs,result:Array;
                try {w.loc.acts=list;w.loc.objs=list;result=r.landmarks.lights(w.loc,layer,rect || view);}
                finally {w.loc.acts=oldActs;w.loc.objs=oldObjs;}
                return result;
            }
            function add(obj:*):* {obj.vis.x=400;obj.vis.y=600;layer.addChild(obj.vis);objs.push(obj);return obj;}
            function find(a:Array,suffix:String):Object {for each(var v:Object in a)if(String(v.id).substr(-suffix.length)==suffix)return v;return null;}
            for(var variant:int=0;variant<=5;variant++) {
                var cp:*=add(new CP(w.loc,"checkpoint"+(variant?variant:""),400,600));
                cp.vis.osn.gotoAndStop(1);cp.vis.fiol.gotoAndStop(1);
                var before:String=JSON.stringify(cp.save()),lights:Array=collect([cp]);
                check(lights.length==2,"checkpoint variant "+variant+" closed pilot lights only");
                check(JSON.stringify(cp.save())==before,"sampling preserves checkpoint variant "+variant+" state");
                cp.vis.osn.gotoAndStop("reopen");check(collect([cp]).length==2,"inactive checkpoint "+variant+" screen stays dark");
                cp.vis.osn.gotoAndStop("open");lights=collect([cp]);
                check(lights.length==3 && find(lights,"-star").color==0xe77aff,"checkpoint "+variant+" open screen uses native violet");
                cp.vis.fiol.gotoAndStop(25);lights=collect([cp]);
                var beamPower:Number=find(lights,"-teleport").power;
                cp.vis.fiol.alpha=0.5;
                check(lights.length==4 && beamPower>0 && Math.abs(find(collect([cp]),"-teleport").power-beamPower*0.5)<0.0001,"checkpoint "+variant+" beam follows native alpha");
                cp.vis.fiol.alpha=1;
                cp.hide=true;check(collect([cp]).length==0,"hidden checkpoint "+variant+" emits nothing");cp.hide=false;
                cp.vis.fiol.gotoAndStop(1);check(collect([cp]).length==3,"checkpoint "+variant+" stale beam is removed");
            }
            cp=objs[0];cp.vis.osn.gotoAndStop("open");cp.vis.fiol.gotoAndStop(1);
            for each(var angle:int in [0,90,180,-90])for each(var facing:int in [-1,1]) {
                cp.vis.rotation=angle;cp.vis.scaleX=facing;var star:Object=find(collect([cp]),"-star");
                var p:Point=cp.vis.localToGlobal(new Point(0.975,-83.925));p=layer.globalToLocal(p);
                check(Math.abs(star.x-p.x)<0.1 && Math.abs(star.y-p.y)<0.1,"star follows artwork transform "+angle+"/"+facing);
            }
            cp.vis.rotation=0;cp.vis.scaleX=1;cp.vis.visible=false;check(collect([cp]).length==0,"invisible terminal has no glow");cp.vis.visible=true;
            cp.vis.alpha=0;check(collect([cp]).length==0,"transparent terminal has no glow");cp.vis.alpha=1;
            check(collect([cp],new Rectangle(3000,3000,100,100)).length==0,"offscreen sources culled");
            layer.removeChild(cp.vis);check(collect([cp]).length==0,"detached terminal has no glow");layer.addChild(cp.vis);
            // Exercise native activation/deactivation rather than changing only the artwork.
            cp.inter.lock=cp.inter.mine=0;cp.active=0;cp.teleOn=true;w.game.mReturn=true;cp.activate(true);
            check(find(collect([cp]),"-star")!=null && find(collect([cp]),"-teleport")!=null,"native activate enables screen and return beam");
            cp.deactivate();check(collect([cp]).length==2,"native deactivate removes screen and beam");
            cp.used=true;cp.activate(true);check(find(collect([cp]),"-star")!=null && find(collect([cp]),"-teleport")==null,"used checkpoint keeps screen but loses beam");
            var doors:Array=[];
            for each(var id:String in ["exit","doorprob","doorboss","doorout"]) {
                var box:*=add(new Box(w.loc,id,400,600));doors.push(box);lights=collect([box]);
                check(lights.length==(id=="doorout"?0:1),id+" native emissive artwork classification");
                if(id=="doorout")continue;
                var color:uint=id=="exit"?0x7be89a:id=="doorprob"?0x7be84a:0xff5149;
                check(lights[0].color==color,id+" matches native sign color");
                var origin:Number=lights[0].y;box.vis.y+=30;box.vis.scaleX=-1;
                check(Math.abs(collect([box])[0].y-origin-30)<0.01,id+" follows native placement and mirroring");
                box.dead=true;check(collect([box]).length==0,id+" destroyed object removed");box.dead=false;
                box.invis=true;check(collect([box]).length==0,id+" hidden object removed");box.invis=false;
                box.hp=0;check(collect([box]).length==0,id+" zero HP removed");box.hp=100;
                box.vis.visible=false;check(collect([box]).length==0,id+" hidden visual removed");box.vis.visible=true;
            }
            check(collect([{id:"exit",loc:w.loc}]).length==0,"unrelated class cannot impersonate exit");
            var crowd:Array=[];for(var i:int=0;i<40;i++)crowd.push(add(new Box(w.loc,"exit",400,600)));
            check(collect(crowd).length==32,"visible light budget capped at 32 despite duplicate containers");
            check(collect([]).length==0,"removed objects leave no sources");r.landmarks.clear();check(collect([]).length==0,"clear releases location identity");
            var Field:Class=r.field.constructor as Class,field:*=new Field(),map:Object={spaceX:30,spaceY:20,space:[]};
            for(var x:int=0;x<30;x++){map.space[x]=[];for(var y:int=0;y<20;y++)map.space[x][y]=LightCoreChecks.tile(x,y);}
            box=doors[0];box.vis.x=300;box.vis.y=411;box.vis.scaleX=1;lights=collect([box]);
            field.render(map,view,[],0.1);var dark:Number=field.sample(300,300);
            field.render(map,view,lights,0.1);check(field.sample(300,300)>dark+0.3,"exit spill lights actual shared illumination field");
            check(field.sample(500,300)==dark,"sign spill remains local");
            for(y=0;y<20;y++)map.space[8][y].opac=1;
            field.render(map,view,lights,0.1);check(field.sample(350,300)<dark+0.01,"opaque wall blocks landmark spill");
            for(y=0;y<20;y++)map.space[8][y].opac=0;
            field.render(map,view,lights,0.1);check(field.sample(350,300)>dark+0.1,"opening the wall restores spill");field.clear();
            check(JSON.stringify(collect([box]))==JSON.stringify(collect([box])),"paused sources deterministic");
            // Six-panel gallery is the actual collector plus production raster over native art.
            while(layer.numChildren)layer.removeChildAt(0);
            layer.graphics.beginFill(0x7c8187);layer.graphics.drawRect(0,0,1200,650);layer.graphics.endFill();
            var gallery:Array=[objs[0],objs[1],objs[2],doors[0],doors[1],doors[2]],labels:Array=["Closed checkpoint","Active checkpoint","Return beam","Exit","Trial","Battle trial"];
            for(i=0;i<gallery.length;i++){
                var o:*=gallery[i];o.vis.scaleX=o.vis.scaleY=1.5;o.vis.rotation=0;o.vis.x=200+(i%3)*400;o.vis.y=270+int(i/3)*310;layer.addChild(o.vis);
                if(i<3){o.vis.osn.gotoAndStop(i==0?1:"open");o.vis.fiol.gotoAndStop(i==2?25:1);}
            }
            view=new Rectangle(0,0,1200,650);field.render(map,view,[],0.14);layer.addChild(field.bitmap);
            var b:BitmapData=new BitmapData(1200,650,false,0);b.draw(layer);png("landmarks-before",b);
            field.render(map,view,collect(gallery),0.14);
            for(i=0;i<6;i++){var t:TextField=new TextField();t.defaultTextFormat=new TextFormat("Arial",16,0xffffff);t.width=390;t.text=labels[i];t.x=i%3*400+12;t.y=int(i/3)*310+12;layer.addChild(t);}
            b=new BitmapData(1200,650,false,0);b.draw(layer);png("landmarks-after",b);field.clear();
            // The real camp checkpoint must be picked up without test object injection.
            r.store.data.headlamp=false;r.setAtmospherePreference("landmarks",false);
            var a:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);a.draw(main.stage);
            check(!JSON.parse(w.game.triggers["lightanddarkness.state.v1"]).atmosphereSettings.landmarks,"landmark toggle persists in native save payload");
            r.setAtmospherePreference("landmarks",true);var count:int=0;for each(var light:Object in r.lights())if(String(light.id).indexOf("landmark-")==0)count++;
            check(count>=3,"runtime discovers actual camp checkpoint");
            b=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);b.draw(main.stage);var diff:*=a.compare(b);
            check(diff is BitmapData,"actual camp image responds to landmark lighting toggle");if(diff is BitmapData)diff.dispose();png("camp-before",a);png("camp-after",b);
            var Atmos:Class=r.atmosphere.constructor as Class,at:*=new Atmos();at.bind(null);check(at.settings.landmarks,"old preferences default landmark lighting on");at.bind({landmarks:false});check(!at.settings.landmarks,"saved disabled preference restored");
            EnvironmentChecks.run(r,function(line:String):void{check(true,"environment regression: "+line);});
        }
    }
}
