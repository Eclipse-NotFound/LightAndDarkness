package {
    import flash.display.*;
    import flash.events.Event;
    import flash.filesystem.*;
    import flash.geom.*;
    import flash.utils.getDefinitionByName;
    public final class BrightnessChecks {
        private static function item(root:*,pageId:String,key:String):Object {
            for each(var p:Object in root.getChildByName("ModSettingsCarrier").modAPI.getPages())
                if(p.modId==pageId)for each(var i:Object in p.items)if(i.key==key)return i;
            return null;
        }
        private static function closePage(root:*,pageId:String):void {
            for each(var p:Object in root.getChildByName("ModSettingsCarrier").modAPI.getPages())if(p.modId==pageId)p.onPageClose();
        }
        private static function write(name:String,value:Object):void {
            var s:FileStream=new FileStream();s.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);s.writeUTFBytes(JSON.stringify(value));s.close();
        }
        public static function run(main:*,w:*,r:*,check:Function,png:Function):void {
            var C:Class=r.lighting.constructor as Class,E:Class=r.environment.constructor as Class,F:Class=r.field.constructor as Class;
            var defaults:*=new C(),saved:Object=r.lighting.snapshot(),fresh:*,key:String,control:Object;
            var file:File=File.applicationStorageDirectory.resolvePath("seed-preferences.json");
            if(file.exists){
                var fs:FileStream=new FileStream();fs.open(file,FileMode.READ);var seeded:Object=JSON.parse(fs.readUTFBytes(fs.bytesAvailable));fs.close();
                var restored:Boolean=saved.version==seeded.version && saved.multiplier==seeded.multiplier && saved.lampRange==seeded.lampRange;
                for(var region:String in seeded.regions)restored=restored && saved.regions[region]==seeded.regions[region];
                check(restored,"new AIR process restores all seeded brightness preferences before first room",{actual:saved,expected:seeded});
            }
            r.lighting.bind(null);r.ambient=.14;
            for each(key in ["outdoor","safe","maintained","interior","abandoned","underground","outage"]){
                control=item(main,"light-and-darkness-regions","base_"+key);
                check(control && control.kind=="slider" && control.min==10 && control.max==100,"regional slider registered: "+key);
                var before:Object=r.lighting.snapshot();control.set(73);closePage(main,"light-and-darkness-regions");fresh=new C();fresh.load();
                check(control.get()==73 && Math.abs(fresh.getLevel(key)-.73)<.0001,"regional slider updates and persists: "+key);
                var independent:Boolean=true;for(var other:String in before.regions)if(other!=key && before.regions[other]!=r.lighting.getLevel(other))independent=false;
                check(independent,"regional slider leaves every other category unchanged: "+key);
                control.set(200);check(control.get()==100,"regional upper clamp: "+key);
                control.set(-20);check(control.get()==10,"regional lower clamp: "+key);
                control.set(Number.NaN);check(Math.abs(control.get()-defaults.getLevel(key)*100)<.001,"regional invalid input uses default: "+key);
            }
            var T:Class=getDefinitionByName("fe.loc.Tile") as Class;
            var map:Object={spaceX:24,spaceY:25,space:[],backwall:"sky",backform:0,transpFon:true,base:false,lightOn:0,color:"",homeStable:false,
                backobjs:[],spawnPoints:[],acts:[],firstObj:null,id:"brightness",land:{act:{id:"random_mane",tip:"test",fon:"fonRuins"}}};
            for(var x:int=0;x<24;x++){map.space[x]=[];for(var y:int=0;y<25;y++){var tile:*=new T(x,y);tile.opac=tile.phis=0;map.space[x][y]=tile;}}
            var env:*=new E(),field:*=new F(),view:Rectangle=new Rectangle(0,0,960,996);
            env.brightness=r.lighting;env.bind(map,null,"brightness-checks");field.render(map,view,[],.14,null,1,env);
            check(field.sample(300,300)==1,"unobstructed outdoor field is neutral white, preserving native brightness");
            var art:BitmapData=new BitmapData(960,996,false,0x735a84),layer:Sprite=new Sprite();layer.addChild(new Bitmap(art));layer.addChild(field.bitmap);
            var rendered:BitmapData=new BitmapData(960,996,false,0);rendered.draw(layer);
            check(rendered.getPixel(300,300)==art.getPixel(300,300),"full daylight MULTIPLY preserves native RGB exactly");rendered.dispose();art.dispose();
            control=item(main,"light-and-darkness-regions","base_outdoor");control.set(50);field.render(map,view,[],.14,null,1,env);
            check(Math.abs(field.sample(300,300)-.5)<.01,"outdoor slider invalidates cached sky field immediately");control.set(100);
            map.backwall="tBackWall";map.transpFon=false;map.land.act.fon="fonDefault";map.land.act.id="test";env.bind(map,null,"interior");
            control=item(main,"light-and-darkness-regions","base_interior");control.set(40);field.render(map,view,[],.14,null,1,env);var low:Number=field.sample(300,300);
            var lamp:Object={id:"fixture",x:300,y:300,radius:330,color:0xffe4b3,power:.8,angle:0,cone:Math.PI*2,staticScene:true};
            field.render(map,view,[lamp],.14,null,1,env);var lowGain:Number=field.sample(300,300)-low;
            control.set(80);field.render(map,view,[],.14,null,1,env);var high:Number=field.sample(300,300);
            field.render(map,view,[lamp],.14,null,1,env);var highGain:Number=field.sample(300,300)-high;
            check(Math.abs(low-.4)<.01 && Math.abs(high-.8)<.01,"interior floor changes immediately through the real UI callback");
            check(lowGain>highGain && highGain>0 && field.sample(300,300)<=1,"lamps add more light to dark rooms and cannot bleach beyond native RGB");
            lamp.power=0;field.render(map,view,[lamp],.14,null,1,env);check(Math.abs(field.sample(300,300)-high)<.01,"dark or broken lamp returns to the regional floor");
            lamp.power=.8;control.set(40);lamp.radius=165;field.render(map,view,[lamp],.14,null,1,env);var narrow:Number=field.sample(510,300);
            lamp.radius=495;field.render(map,view,[lamp],.14,null,1,env);check(field.sample(510,300)>narrow+.05,"wider fixture range reaches previously unlit nearby ground");
            var count:int=field.rebuilds;for(var n:int=0;n<16;n++)field.render(map,view,[lamp],.14,null,1,env);
            check(field.rebuilds==count,"unchanged wider fixture reuses its shadow raster over sixteen frames");
            field.clear();env.clear();
            control=item(main,"light-and-darkness","lampRange");check(control && control.kind=="slider","fixture range slider registered");control.set(1.3);
            item(main,"light-and-darkness","ambient").set(1.15);
            item(main,"light-and-darkness-regions","base_safe").set(73);item(main,"light-and-darkness-regions","base_outdoor").set(91);
            closePage(main,"light-and-darkness");fresh=new C();fresh.load();check(fresh.lampRange==1.3 && fresh.multiplier==1.15 && fresh.getLevel("safe")==.73,"range, total multiplier and regional values share persistent preferences");
            var settingsBefore:String=JSON.stringify(r.lighting.snapshot());r.store.bind(w.game);
            check(settingsBefore==JSON.stringify(r.lighting.snapshot()),"loading a world save cannot overwrite visual preferences");
            write("cold-preferences.json",r.lighting.snapshot());
            r.lighting.bind(null);r.ambient=.14;r.lighting.save();r.render();
            check(r.lighting.lampRange==1.10 && r.lighting.getLevel("outdoor")==1,"visual comparisons use the new defaults");
        }
        public static function ui(main:*,check:Function,png:Function):void {
            var rows:Array=[];
            function collect(obj:DisplayObject):void {
                if(!obj)return;
                if(obj.name && obj.name.indexOf("SettingsItem:base_")==0)rows.push(obj);
                if(obj is DisplayObjectContainer)for(var i:int=0;i<DisplayObjectContainer(obj).numChildren;i++)collect(DisplayObjectContainer(obj).getChildAt(i));
            }
            collect(main);check(rows.length==7,"all seven regional sliders are visible on the native settings page");
            var row:*=rows[0],slider:*=row.settingsSc,control:Object=row.settingsItem;
            if(slider){
                var old:*=control.get();slider.scrollPosition=(75-control.min)/control.step;slider.dispatchEvent(new Event("scroll"));
                check(control.get()==75,"native slider scroll event changes the regional brightness");control.set(old);
            }
            var shot:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);shot.draw(main.stage);png("regional-settings",shot);shot.dispose();
        }
    }
}
