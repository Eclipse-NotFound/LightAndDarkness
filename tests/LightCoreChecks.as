package {
    import flash.geom.Rectangle;
    import flash.utils.getTimer;
    public final class LightCoreChecks {
        public static function run(runtime:*,log:Function):void {
            var FieldClass:Class=runtime.field.constructor as Class;
            var field:*=new FieldClass();
            var map:Object={spaceX:24,spaceY:18,space:[]};
            for(var x:int=0;x<24;x++) {
                map.space[x]=[];
                for(var y:int=0;y<18;y++) map.space[x][y]={opac:x==10?1:0};
            }
            var view:Rectangle=new Rectangle(0,0,800,600);
            var lamp:Object={id:"test",x:300,y:300,radius:360,color:0xffffff,power:1,angle:0,cone:Math.PI*2};
            field.render(map,view,[lamp],0.14);
            check(field.bitmap.smoothing,"resized illumination retains smooth interpolation",log);
            var closed:Number=field.sample(500,300),lit:Number=field.sample(340,300);
            check(closed<0.16 && lit>0.7,"opaque wall",log);
            map.space[10][7].opac=0;
            field.render(map,view,[lamp],0.14);
            check(field.sample(500,300)>closed+0.2,"opening door invalidates light cache",log);
            map.space[10][7].opac=1;
            field.render(map,view,[lamp],0.14);
            check(field.sample(500,300)<0.16,"closing door restores shadow",log);
            lamp.cone=Math.PI/2;field.render(map,view,[lamp],0.14);
            var front:Number=field.sample(350,300),back:Number=field.sample(240,300);
            check(front>0.6 && back<0.16,"directional cone",log);
            lamp.angle=Math.PI;field.render(map,view,[lamp],0.14);
            check(field.sample(350,300)<0.16 && field.sample(240,300)>0.6,"turning dynamic lamp",log);
            lamp.x=220;field.render(map,view,[lamp],0.14);
            check(field.sample(170,300)>0.6,"moving dynamic lamp",log);
            field.render(map,view,[],0.14);check(field.sample(170,300)<0.16,"light removal",log);
            var times:Array=[];
            for(var i:int=0;i<180;i++) {
                lamp.x=250+(i%24);lamp.angle=i/90;
                var started:int=getTimer();field.render(map,view,[lamp],0.14);times.push(getTimer()-started);
            }
            times.sort(Array.NUMERIC);log("PERF synthetic render n=180 p50="+times[90]+" p95="+times[171]+" max="+times[179]);
            field.clear();
            var StoreClass:Class=runtime.store.constructor as Class;
            var store:*=new StoreClass(),game:Object={triggers:[]};
            store.bind(game);check(store.writable && store.data.headlamp,"old save defaults",log);
            game.triggers["lightanddarkness.state.v1"]='{"version":99,"rooms":{}}';
            store.bind(game);store.flush();
            check(!store.writable && game.triggers["lightanddarkness.state.v1"]=='{"version":99,"rooms":{}}',"unknown state retained",log);
        }
        public static function check(pass:Boolean,label:String,log:Function):void {
            if(!pass) throw new Error("ASSERT "+label);
            log("PASS "+label);
        }
    }
}
