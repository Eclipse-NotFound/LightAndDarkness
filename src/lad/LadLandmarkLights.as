package lad {
    import flash.display.DisplayObject;
    import flash.display.DisplayObjectContainer;
    import flash.display.MovieClip;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.Dictionary;
    import flash.utils.getQualifiedClassName;

    /** Spill from native checkpoint panels, EXIT lettering and trial-door symbols. */
    public final class LadLandmarkLights {
        private var identities:Dictionary=new Dictionary(true);
        private var location:*;
        private var serial:uint=0;
        public function clear():void {identities=new Dictionary(true);location=null;serial=0;}
        public function lights(loc:*,visual:DisplayObjectContainer,view:Rectangle):Array {
            if(location!==loc){clear();location=loc;}
            var result:Array=[];
            if(!loc || !visual || !view)return result;
            var seen:Dictionary=new Dictionary(true);
            for each(var list:Array in [loc.acts,loc.objs]) for each(var obj:* in list) {
                if(!obj || seen[obj] || obj.loc!==loc)continue;seen[obj]=true;
                var identity:Object=identities[obj];
                if(!identity) {
                    var cls:String=getQualifiedClassName(obj),kind:String="";
                    if(cls=="fe.loc::CheckPoint")kind="checkpoint";
                    else if(cls=="fe.loc::Box" && ["exit","doorprob","doorboss"].indexOf(String(obj.id))>=0)kind=String(obj.id);
                    identity={kind:kind,id:"landmark-"+(++serial)};identities[obj]=identity;
                }
                if(!identity.kind)continue;
                var vis:DisplayObjectContainer=obj.vis as DisplayObjectContainer;
                if(!vis || opacity(vis,visual)<=0)continue;
                if(identity.kind=="checkpoint") {
                    if(obj.hide)continue;
                    // Original pale side indicators remain subtle on closed/locked terminals.
                    add(result,identity.id+"-left",vis,new Point(-33,-96),visual,view,0xc9bfac,64,0.16);
                    add(result,identity.id+"-right",vis,new Point(33,-96),visual,view,0xc9bfac,64,0.16);
                    var osn:MovieClip=vis.getChildByName("osn") as MovieClip;
                    if(osn)for(var i:int=0;i<osn.numChildren;i++) {
                        var child:DisplayObject=osn.getChildAt(i),b:Rectangle=child.getBounds(child);
                        // Native open screen's star is an unnamed 26.05 x 30.05 clip.
                        if(b.width>25 && b.width<27 && b.height>29 && b.height<31)
                            add(result,identity.id+"-star",child,new Point(b.x+b.width/2,b.y+b.height/2),visual,view,0xe77aff,180,0.55);
                    }
                    var fiol:MovieClip=vis.getChildByName("fiol") as MovieClip;
                    if(fiol && fiol.numChildren) {
                        child=fiol.getChildAt(0);b=child.getBounds(child);
                        if(!b.isEmpty())add(result,identity.id+"-teleport",child,new Point(b.x+b.width/2,b.y+b.height/2),visual,view,0xd765ff,215,0.70);
                    }
                } else {
                    if(obj.dead || obj.invis || obj.hp<=0)continue;
                    // These three native door artworks are a single static shape.
                    // Coordinates locate the painted sign, not the center of the metal door.
                    var exit:Boolean=identity.kind=="exit",boss:Boolean=identity.kind=="doorboss";
                    add(result,identity.id,vis,new Point(0,exit?-111:boss?-65:-58),visual,view,
                        exit?0x7be89a:boss?0xff5149:0x7be84a,exit?135:boss?165:155,exit?0.48:boss?0.48:0.44);
                }
            }
            if(result.length>32){result.sortOn("distance",Array.NUMERIC);result.length=32;}
            return result;
        }
        private function add(result:Array,id:String,source:DisplayObject,point:Point,visual:DisplayObjectContainer,view:Rectangle,color:uint,radius:Number,power:Number):void {
            var alpha:Number=opacity(source,visual);if(alpha<=0)return;
            point=visual.globalToLocal(source.localToGlobal(point));
            if(!isFinite(point.x) || !isFinite(point.y) || !view.intersects(new Rectangle(point.x-radius,point.y-radius,2*radius,2*radius)))return;
            var dx:Number=point.x-view.x-view.width/2,dy:Number=point.y-view.y-view.height/2;
            result.push({id:id,x:point.x,y:point.y,color:color,radius:radius,power:power*alpha,angle:0,cone:Math.PI*2,transient:true,distance:dx*dx+dy*dy});
        }
        private function opacity(child:DisplayObject,ancestor:DisplayObject):Number {
            var alpha:Number=1;
            while(child && child!==ancestor){if(!child.visible)return 0;alpha*=child.alpha;if(alpha<=0)return 0;child=child.parent;}
            return child===ancestor?alpha:0;
        }
    }
}
