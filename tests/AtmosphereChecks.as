package {
    import flash.geom.Rectangle;
    public final class AtmosphereChecks {
        public static function run(runtime:*,log:Function):void {
            var AtmosphereClass:Class=runtime.atmosphere.constructor as Class;
            var a:*=new AtmosphereClass();
            var style:Object={mode:"steady",brightness:0.65,frequency:1};
            check(a.wave(style,0)==1 && a.wave(style,12.7)==1,"steady light has no temporal modulation",log);
            var one:Object=a.style(null,"room#fixture","light1","test","room");
            check(JSON.stringify(one)==JSON.stringify(a.style(null,"room#fixture","light1","test","room")),"fixture defaults deterministic across discovery",log);
            var invalid:Object=a.style({mode:"bad",brightness:-8,frequency:999},"x","light1","test","room");
            check(invalid.mode=="steady" && invalid.brightness==0.1 && invalid.frequency==4,"invalid fixture settings bounded",log);
            var slow:int=crossings(a,1),fast:int=crossings(a,3);
            check(fast>=slow*2.8 && fast<=slow*3.2,"frequency controls observed transition count",log);
            style.mode="slow";
            check(a.wave(style,0)>0.99 && a.wave(style,0.5)<0.09,"slow fault fades through bright and dim",log);
            style.mode="burst";
            check(a.wave(style,0.02)>0.9 && a.wave(style,0.16)<0.05 && a.wave(style,0.23)>0.7 && a.wave(style,0.7)<0.05,"burst fault has multiple failed starts and blackout",log);
            check(a.wave(style,0,0)!=a.wave(style,0,0.7),"fixture phases avoid synchronized flicker",log);
            a.settings.flicker=false;
            check(a.wave(style,0.7)==1,"flicker preference produces stable output",log);
            a.settings.flicker=true;
            var lamp:Object={state:{hp:40,on:true,atmosphere:style},powered:true,phase:0};
            lamp.state.on=false;check(a.power(lamp,0)==0,"switch-off overrides atmosphere",log);
            lamp.state.on=true;lamp.powered=false;check(a.power(lamp,0)==0,"power outage overrides atmosphere",log);
            lamp.powered=true;lamp.state.hp=0;check(a.power(lamp,0)==0,"broken lamp overrides atmosphere",log);
            var map:Object={spaceX:30,spaceY:20,space:[],sky:false,id:"room",land:{act:{id:"test"}}};
            for(var x:int=0;x<30;x++){map.space[x]=[];for(var y:int=0;y<20;y++) map.space[x][y]={opac:0};}
            var zones:Array=a.zones(map,"fixed-room");
            check(JSON.stringify(zones)==JSON.stringify(a.zones(map,"fixed-room")),"dark pockets deterministic",log);
            map.sky=true;check(a.zones(map,"fixed-room").length==0,"outdoors excluded from automatic dark pockets",log);map.sky=false;
            a.config={version:1,autoDarkZones:false,lamps:[{land:"test",type:"light1",mode:"fast",brightness:0.4,frequency:1.5}],darkZones:[{land:"test",room:"room",x:40,y:40,width:200,height:200,feather:40,factor:0.1}]};
            check(a.style(null,"room#key","light1","test","room").frequency==1.5 && a.zones(map,"fixed-room").length==1,"authored fixture and region rules applied",log);
            var authored:Object=a.style(null,"room#key","light1","test","room");authored.mode="steady";
            check(a.style(authored,"room#key","light1","test","room").mode=="steady","unchanged authored rule preserves repaired lamp",log);
            a.config.lamps[0].frequency=2.5;
            check(a.style(authored,"room#key","light1","test","room").frequency==2.5,"changed authored rule updates existing fixture",log);
            var FieldClass:Class=runtime.field.constructor as Class,field:*=new FieldClass();
            var view:Rectangle=new Rectangle(0,0,800,600);
            var light:Object={id:"atmosphere",x:300,y:300,radius:300,color:0xffffff,power:0.3,angle:0,cone:Math.PI*2};
            field.render(map,view,[light],0.2);var dim:Number=field.sample(300,300),count:int=field.rebuilds;
            light.power=0.65;field.render(map,view,[light],0.2);var medium:Number=field.sample(300,300);
            light.power=1;field.render(map,view,[light],0.2);var bright:Number=field.sample(300,300);
            check(dim<medium-0.15 && medium<bright-0.15,"brightness levels produce distinct rendered exposure",log);
            light.power=0;field.render(map,view,[light],0.2);light.power=1;field.render(map,view,[light],0.2);
            check(field.rebuilds==count,"flicker including blackout reuses shadow geometry",log);
            var dark:Array=[{x:120,y:120,width:360,height:360,feather:100,factor:0.05}];
            field.render(map,view,[],0.2,dark,1);
            var center:Number=field.sample(300,300),edge:Number=field.sample(140,300),outside:Number=field.sample(60,300);
            check(center<0.02 && edge>center && edge<outside && outside>0.19,"dark region has dark core and soft boundary",log);
            field.render(map,new Rectangle(24,0,800,600),[],0.2,dark,1);
            check(Math.abs(field.sample(300,300)-center)<0.005,"dark region stays in world space when camera moves",log);
            field.render(map,view,[light],0.2,dark,1);
            check(field.sample(300,300)>0.9,"actual light illuminates a dark region",log);
            field.render(map,view,[],0.2,dark,0);
            check(field.sample(300,300)>0.19,"zero darkness restores ambient floor",log);
            field.clear();
        }
        private static function crossings(a:*,frequency:Number):int {
            var style:Object={mode:"fast",frequency:frequency},count:int=0,was:Boolean=false;
            for(var i:int=0;i<1200;i++) {var bright:Boolean=a.wave(style,i/120)>0.8;if(bright && !was) count++;was=bright;}
            return count;
        }
        private static function check(pass:Boolean,label:String,log:Function):void {LightCoreChecks.check(pass,label,log);}
    }
}
