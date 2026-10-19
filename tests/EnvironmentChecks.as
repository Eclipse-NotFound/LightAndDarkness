package {
    import flash.display.Sprite;
    import flash.geom.Rectangle;
    import flash.utils.getDefinitionByName;
    public final class EnvironmentChecks {
        public static function run(runtime:*,log:Function):void {
            var Env:Class=runtime.environment.constructor as Class,Field:Class=runtime.field.constructor as Class;
            var env:*=new Env(),field:*=new Field(),map:Object=room(),view:Rectangle=new Rectangle(0,0,960,1000);
            env.bind(map,null,"fixture");
            check(env.profile(300,300).ambient>=0.35,"ordinary interior has a readable ambient floor",log);
            map.sky=true;env.bind(map,null,"fixture");field.render(map,view,[],0.14,null,1,env);
            check(field.sample(300,300)<0.45,"flight flag alone does not imply daylight",log);
            map.sky=false;map.backwall="sky";env.bind(map,null,"fixture");field.render(map,view,[],0.14,null,1,env);
            check(field.sample(300,300)>0.65,"ordinary sky background receives daylight without flight flag",log);
            map.backwall="tBackWall";map.backform=2;env.bind(map,null,"fixture");field.render(map,view,[],0.14,null,1,env);
            check(field.sample(300,300)>0.65 && field.sample(300,940)<0.45,"roof cutout keeps covered lower floors darker",log);
            map.backform=0;
            var styles:Array=[{bounds:new Rectangle(0,0,400,1000),style:{backwall:"sky",backform:0,color:"",homeStable:false}},
                {bounds:new Rectangle(400,0,560,1000),style:{backwall:"tBackWall",backform:0,color:"",homeStable:false}}];
            var g:Object={sceneRegionSlices:function(...args):Array{return styles;}};
            for(var y:int=0;y<25;y++)map.space[10][y].opac=map.space[10][y].phis=1;
            env.bind(map,g,"mixed");field.render(map,view,[],0.14,null,1,env);var closed:Number=field.sample(500,300);
            check(field.sample(300,300)>0.65 && closed<0.45,"mixed scene assigns outdoor and indoor light locally",log);
            map.space[10][7].opac=map.space[10][7].phis=0;field.render(map,view,[],0.14,null,1,env);
            check(field.sample(500,300)>closed+0.08,"opening a door admits nearby sky spill",log);
            map.space[10][7].opac=map.space[10][7].phis=1;field.render(map,view,[],0.14,null,1,env);
            check(Math.abs(field.sample(500,300)-closed)<0.005,"closing a door restores sky occlusion",log);
            for(var x:int=0;x<10;x++)for(y=0;y<25;y++)map.space[x][y].back="tConcrete";
            field.render(map,view,[],0.14,null,1,env);
            check(field.sample(300,300)<0.45,"masonry behind a sky backdrop is treated as covered",log);
            for(x=0;x<10;x++)for(y=0;y<25;y++)map.space[x][y].back="";
            field.render(map,view,[],0.14,null,1,env);
            check(field.sample(300,300)>0.65,"removed background masonry refreshes daylight",log);
            field.render(map,new Rectangle(5000,3000,800,600),[],0.14,null,1,env);
            check(field.data!=null,"camera beyond map bounds retains a valid environment raster",log);
            map=room();map.land.act.id="random_mane";
            var aperture:Sprite=new Sprite();aperture.graphics.beginFill(0xffffff);aperture.graphics.drawRect(0,0,80,120);aperture.graphics.endFill();
            map.backobjs=[{id:"fwindow",X:240,Y:240,scX:1,scY:1,alpha:1,erase:aperture}];env.bind(map,null,"window");
            check(env.openings.length>0,"actual aperture alpha generates window sources",log);
            field.render(map,view,env.lights(view),0.14,null,1,env);var windowLit:Number=field.sample(300,300);
            check(windowLit>0.6,"window aperture illuminates the shared gameplay field",log);
            for(y=0;y<25;y++)map.space[10][y].opac=1;
            field.render(map,view,env.lights(view),0.14,null,1,env);
            check(field.sample(500,300)<0.38,"window light cannot cross an opaque wall",log);
            map.backobjs[0].id="stwindow";env.bind(map,null,"window");check(env.openings.length==0,"sealed observation windows are not daylight sources",log);
            map.backobjs[0].id="fwindow";map.land.act.id="random_sewer";env.bind(map,null,"window");
            check(env.openings.length==0,"underground decoration does not invent outdoor daylight",log);
            var Back:Class=getDefinitionByName("fe.graph.BackObj") as Class;
            for each(var nativeID:String in ["fwindow","bwindow","swindow","cwindow","awindow","enclwindow"]) {
                var nativeWindow:*=new Back(runtime.location,nativeID,240,240);
                map.land.act.id="random_plant";map.backobjs=[nativeWindow];env.bind(map,null,"native-window");
                check(env.openings.length>0,"native aperture produces light: "+nativeID,log);
            }
            map.land.act.id="rbl";map.base=true;env.bind(map,null,"safe");
            check(env.profile(100,100).ambient>=0.55 && env.pockets().length==0,"safe hub keeps readable ambient and no automatic dark pockets",log);
            var Atmos:Class=runtime.atmosphere.constructor as Class,a:*=new Atmos();
            for(x=0;x<100;x++) {var safe:Object=a.style(null,"lamp"+x,"light1","rbl","room",env.profile(100,100));if(safe.mode!="steady" || safe.brightness<0.8)throw new Error("safe lamp randomized into failure");}
            check(true,"safe fixtures consistently use stable bright defaults",log);
            map=room();map.land.act.id="random_sewer";
            // Repeated roofed alcoves, away from authored entrance and interaction anchors.
            for(x=0;x<24;x++) {map.space[x][10].phis=map.space[x][10].opac=1;map.space[x][6].phis=map.space[x][6].opac=1;}
            for(x=2;x<24;x+=4)map.space[x][9].opac=1;
            env.bind(map,null,"alcove-1");var zones:Array=env.pockets();
            var attempt:int=1;while(!zones.length && attempt<30){env.bind(map,null,"alcove-"+(++attempt));zones=env.pockets();}
            check(zones.length>0,"abandoned roofed alcove can form a bounded dark pocket",log);
            var zone:Object=zones[0];map.spawnPoints=[{x:(zone.x+120)/40,y:(zone.y+80)/40}];env.bind(map,null,"alcove-"+attempt);
            check(env.protectedAt(zone.x+120,zone.y+80) && env.pockets().length<zones.length,"entrance protection removes nearby pockets",log);
            map.spawnPoints=[];env.bind(map,null,"alcove-"+attempt);check(JSON.stringify(zones)==JSON.stringify(env.pockets()),"pockets are stable across rebinding the same map",log);
            map.firstObj={X:zone.x+120,Y:zone.y+80,inter:{cont:"loot"},nobj:null};env.bind(map,null,"alcove-"+attempt);
            check(JSON.stringify(zones)==JSON.stringify(env.pockets()),"ordinary loot does not erase a deliberate dark alcove",log);
            map.firstObj.inter.door=1;env.bind(map,null,"alcove-"+attempt);
            check(env.pockets().length<zones.length,"door interaction remains protected while ordinary loot is allowed",log);
            var old:Object={mode:"steady",brightness:0.35,frequency:1,source:"auto-v1"};
            var migrated:Object=a.style(old,"old#lamp","light1","rbl","room",{safe:true,faults:0,abandoned:false});
            check(migrated.mode=="steady" && migrated.brightness>=0.8 && migrated.source=="auto-v2","old repaired or steady auto lamp remains steady after migration",log);
            old={mode:"fast",brightness:0.45,frequency:2,source:"auto-v1"};
            migrated=a.style(old,"old#lamp","light1","rbl","room",{safe:true,faults:0,abandoned:false});
            check(migrated.mode=="steady","legacy automatic fault removed in safe hub",log);
            var unchanged:Object=a.style({mode:"steady",brightness:0.45,frequency:1,source:"auto-v2",repaired:true},"old#lamp","light1","sewer","room",{safe:false,faults:100,abandoned:true});
            check(unchanged.mode=="steady" && unchanged.repaired && unchanged.brightness==0.45,"repaired v2 lamp survives changed scene fault rate",log);
            field.clear();env.clear();
        }
        private static function room():Object {
            var m:Object={spaceX:24,spaceY:25,space:[],backwall:"tBackWall",backform:0,sky:false,base:false,lightOn:0,color:"",homeStable:false,transpFon:false,backobjs:[],spawnPoints:[],acts:[],id:"test",land:{act:{id:"test",tip:"test"}}};
            for(var x:int=0;x<24;x++){m.space[x]=[];for(var y:int=0;y<25;y++)m.space[x][y]={opac:0,phis:0,back:"",front:"",fRear:false};}return m;
        }
        private static function check(pass:Boolean,label:String,log:Function):void {LightCoreChecks.check(pass,label,log);}
    }
}
