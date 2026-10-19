package {
    import flash.display.*;
    import flash.geom.*;
    import flash.text.*;
    import flash.filesystem.*;
    import flash.utils.*;
    public final class TerminalLightChecks {
        public static function run(w:*,r:*,check:Function,png:Function):void {
            var Box:Class=getDefinitionByName("fe.loc.Box") as Class,board:Sprite=new Sprite(),view:Rectangle=new Rectangle(0,0,1200,400);
            var ids:Array=["term","term1","term2","term3","termh","elpanel"],set:Array=[];
            function collect(list:Array,rect:Rectangle=null):Array {
                var acts:Array=w.loc.acts,objs:Array=w.loc.objs,result:Array;
                try {w.loc.acts=list;w.loc.objs=list;result=r.landmarks.lights(w.loc,board,rect || view);}
                finally {w.loc.acts=acts;w.loc.objs=objs;}return result;
            }
            for(var i:int=0;i<ids.length;i++) {
                var obj:*=new Box(w.loc,ids[i],400,300);obj.vis.x=400;obj.vis.y=300;board.addChild(obj.vis);
                obj.inter.setAct("lock",3);var saved:String=JSON.stringify(obj.save()),a:Array=collect([obj]);
                check(a.length==1 && a[0].color==(ids[i]=="elpanel"?0xffdf47:0x91d85c),ids[i]+" light matches native screen color");
                check(saved==JSON.stringify(obj.save()),ids[i]+" sampling does not mutate native save");
                var bright:Number=a[0].power;check(bright>0 && bright<0.42,ids[i]+" screen stays softer than turret");
                obj.inter.setAct("lock",0);check(collect([obj])[0].power==bright,ids[i]+" never locked is not falsely hacked");
                obj.inter.setAct("lock",102);check(collect([obj])[0].power==bright,ids[i]+" failed hack is not success");
                obj.inter.setAct("lock",3);obj.inter.is_hack=true;obj.inter.command("hack");
                var dim:Object=collect([obj])[0];check(dim.power<bright*0.5 && dim.radius<a[0].radius,ids[i]+" native hack dims and shrinks screen spill");
                var snapshot:Object=obj.save();check(snapshot.lock==101,ids[i]+" native save records successful hack");
                var restored:*=new Box(w.loc,ids[i],400,300,null,snapshot);board.addChild(restored.vis);
                check(collect([restored])[0].power==dim.power,ids[i]+" native reconstruction retains dim light");board.removeChild(restored.vis);
                obj.vis.alpha=0.5;check(Math.abs(collect([obj])[0].power-dim.power*0.5)<0.0001,ids[i]+" follows artwork alpha");obj.vis.alpha=1;
                obj.vis.visible=false;check(collect([obj]).length==0,ids[i]+" hidden visual off");obj.vis.visible=true;
                obj.invis=true;check(collect([obj]).length==0,ids[i]+" hidden object off");obj.invis=false;
                obj.dead=true;check(collect([obj]).length==0,ids[i]+" destroyed off");obj.dead=false;
                var hp:Number=obj.hp;obj.hp=0;check(collect([obj]).length==0,ids[i]+" zero HP off");obj.hp=hp;
                check(collect([obj],new Rectangle(3000,3000,100,100)).length==0,ids[i]+" offscreen culled");
                board.removeChild(obj.vis);check(collect([obj]).length==0,ids[i]+" detached off");
                board.addChild(obj.vis);obj.inter.setAct("lock",3);set.push(obj);
            }
            var field:*=new (r.field.constructor as Class)(),map:Object={spaceX:30,spaceY:10,space:[]};
            for(var x:int=0;x<30;x++){map.space[x]=[];for(var y:int=0;y<10;y++)map.space[x][y]={opac:0};}
            obj=set[0];obj.vis.x=300;obj.vis.y=225;var lights:Array=collect([obj]);
            field.render(map,view,[],0.14);var dark:Number=field.sample(300,200);
            field.render(map,view,lights,0.14);var lit:Number=field.sample(300,200);check(lit>dark+0.10,"terminal changes shared illumination pixels");
            for(y=0;y<10;y++)map.space[8][y].opac=1;
            field.render(map,view,lights,0.14);check(field.sample(345,200)<dark+0.01,"wall occludes terminal glow");
            for(y=0;y<10;y++)map.space[8][y].opac=0;
            obj.inter.command("hack");field.render(map,view,collect([obj]),0.14);check(field.sample(300,200)<lit-0.08,"native hack visibly dims actual pixels");
            while(board.numChildren)board.removeChildAt(0);
            board.graphics.beginFill(0x7c8187);board.graphics.drawRect(0,0,1200,400);board.graphics.endFill();
            for(i=0;i<set.length;i++){obj=set[i];obj.vis.scaleX=obj.vis.scaleY=2;obj.vis.x=i*200+100;obj.vis.y=230;obj.inter.setAct("lock",3);board.addChild(obj.vis);}
            field.render(map,view,collect(set),0.14);board.addChild(field.bitmap);var image:BitmapData=new BitmapData(1200,400,false,0);image.draw(board);png("terminals-unhacked",image);
            for each(obj in set)obj.inter.command("hack");field.render(map,view,collect(set),0.14);image=new BitmapData(1200,400,false,0);image.draw(board);png("terminals-hacked",image);field.clear();
        }
        public static function atlas(w:*,png:Function):void {
            var Box:Class=getDefinitionByName("fe.loc.Box") as Class,board:Sprite=new Sprite(),records:Array=[];
            board.graphics.beginFill(0x30343a);board.graphics.drawRect(0,0,1200,400);board.graphics.endFill();
            var ids:Array=["term","term1","term2","term3","termh","elpanel"];
            for(var i:int=0;i<ids.length;i++) {
                var obj:*=new Box(w.loc,ids[i],400,600),v:MovieClip=obj.vis;
                records.push({id:ids[i],save:obj.save(),tree:tree(v)});
                var b:Rectangle=v.getBounds(v);v.scaleX=v.scaleY=3;v.x=i*200+100-(b.x+b.width/2)*3;v.y=80-b.y*3;board.addChild(v);
                var label:TextField=new TextField();label.defaultTextFormat=new TextFormat("Arial",17,0xffffff);label.text=ids[i];label.width=190;label.x=i*200+10;label.y=15;board.addChild(label);
            }
            var data:BitmapData=new BitmapData(1200,400,false,0);data.draw(board);png("terminal-native-atlas",data);
            var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("terminal-native-tree.json"),FileMode.WRITE);f.writeUTFBytes(JSON.stringify(records,null,2));f.close();
        }
        private static function tree(v:DisplayObject,depth:int=0):Object {
            var b:Rectangle=v.getBounds(v),o:Object={name:v.name,type:getQualifiedClassName(v),x:v.x,y:v.y,bounds:b.toString(),visible:v.visible,alpha:v.alpha};
            if(v is MovieClip){o.frame=MovieClip(v).currentFrame;o.frames=MovieClip(v).totalFrames;}
            if(v is DisplayObjectContainer && depth<4){o.children=[];for(var i:int=0;i<DisplayObjectContainer(v).numChildren;i++)o.children.push(tree(DisplayObjectContainer(v).getChildAt(i),depth+1));}return o;
        }
    }
}
