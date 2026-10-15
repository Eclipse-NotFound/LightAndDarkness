package lad {
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.BlendMode;
    import flash.display.GradientType;
    import flash.display.Sprite;
    import flash.geom.ColorTransform;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.getTimer;

    /** Viewport raster and gameplay samples use the same current illumination. */
    public final class LadLightField {
        public const cell:int = 12;
        public var bitmap:Bitmap = new Bitmap(null,"auto",true);
        public var data:BitmapData;
        public var bounds:Rectangle = new Rectangle();
        public var elapsedMs:int = 0;
        public var rebuilds:int = 0;
        private var cache:Object = {};
        private var terrainHash:uint = 0;
        private var terrainRegion:String = "";
        private var loc:*;
        private var background:BitmapData;
        private var backgroundKey:String="";
        public function LadLightField() {
            bitmap.name = "LightAndDarknessIllumination";
            bitmap.blendMode = BlendMode.MULTIPLY;
            bitmap.scaleX = bitmap.scaleY = cell;
        }
        public function clear():void {
            for each(var item:Object in cache) item.data.dispose();
            cache = {}; terrainHash = 0; terrainRegion = ""; loc = null;
            if(data) data.dispose(); data=null; bitmap.bitmapData=null;
            if(background) background.dispose();background=null;backgroundKey="";
            if(bitmap.parent) bitmap.parent.removeChild(bitmap);
        }
        public function render(location:*, view:Rectangle, lights:Array, ambient:Number,zones:Array=null,darkness:Number=1):void {
            var started:int = getTimer();
            if(loc !== location) { clear(); loc = location; }
            var vx:int = Math.floor(view.x/cell)*cell-cell;
            var vy:int = Math.floor(view.y/cell)*cell-cell;
            var width:int = Math.ceil((view.right-vx)/cell)+2;
            var height:int = Math.ceil((view.bottom-vy)/cell)+2;
            if(data == null || data.width != width || data.height != height) {
                if(data) data.dispose(); data=new BitmapData(width,height,false,0);
                bitmap.bitmapData=data;
                // AIR resets smoothing when bitmapData is replaced; restore it on every resize.
                bitmap.smoothing=true;
            }
            bounds.setTo(vx,vy,width*cell,height*cell);
            bitmap.x=vx; bitmap.y=vy;
            var scan:Rectangle=view.clone(); scan.inflate(600,600);
            var left:int=Math.max(0,int(scan.left/40));
            var top:int=Math.max(0,int(scan.top/40));
            var right:int=Math.min(loc.spaceX-1,int(scan.right/40));
            var bottom:int=Math.min(loc.spaceY-1,int(scan.bottom/40));
            var hash:uint=2166136261;
            for(var x:int=left;x<=right;x++) for(var y:int=top;y<=bottom;y++) {
                hash ^= uint(Math.max(0,Math.min(255,Number(loc.space[x][y].opac)*255)));
                hash += (hash<<1)+(hash<<4)+(hash<<7)+(hash<<8)+(hash<<24);
            }
            var region:String=[left,top,right,bottom].join(":");
            if(hash!=terrainHash || region!=terrainRegion) {
                for each(var old:Object in cache) old.data.dispose(); cache={};
                terrainHash=hash;terrainRegion=region;
            }
            ambientBackground(ambient,zones,darkness);
            data.lock(); data.copyPixels(background,background.rect,new Point());
            var alive:Object={};
            for each(var light:Object in lights) {
                if(!bounds.intersects(new Rectangle(light.x-light.radius,light.y-light.radius,light.radius*2,light.radius*2))) continue;
                var identity:String=String(light.id);
                alive[identity]=true;
                // A momentary blackout retains its shadow geometry for the next lit frame.
                if(light.power<=0) continue;
                var signature:String=[int(light.x/4),int(light.y/4),light.radius,int(light.angle*90/Math.PI),light.cone].join(":");
                var entry:Object=cache[identity];
                if(entry==null || entry.key!=signature) {
                    if(entry) entry.data.dispose();
                    entry={key:signature,data:makeLight(light)};cache[identity]=entry;rebuilds++;
                }
                var color:uint=uint(light.color);
                var transform:ColorTransform=new ColorTransform(((color>>16)&255)/255*light.power,
                    ((color>>8)&255)/255*light.power,(color&255)/255*light.power,1);
                var matrix:Matrix=new Matrix(1,0,0,1,(light.x-light.radius-vx)/cell,(light.y-light.radius-vy)/cell);
                data.draw(entry.data,matrix,transform,BlendMode.SCREEN,null,true);
            }
            for(var key:String in cache) if(!alive[key]) {cache[key].data.dispose();delete cache[key];}
            data.unlock();elapsedMs=getTimer()-started;
        }
        private function ambientBackground(ambient:Number,zones:Array,darkness:Number):void {
            var signature:String=[bounds.x,bounds.y,data.width,data.height,ambient,darkness,JSON.stringify(zones)].join(":");
            if(signature==backgroundKey && background) return;
            if(background) background.dispose();
            var shade:int=Math.max(0,Math.min(255,int(ambient*255)));
            background=new BitmapData(data.width,data.height,false,(shade<<16)|(shade<<8)|shade);
            if(zones && darkness>0) for each(var zone:Object in zones) {
                var rect:Rectangle=new Rectangle(zone.x,zone.y,zone.width,zone.height);
                if(!bounds.intersects(rect)) continue;
                var left:int=Math.max(0,int((rect.left-bounds.x)/cell));
                var top:int=Math.max(0,int((rect.top-bounds.y)/cell));
                var right:int=Math.min(data.width,Math.ceil((rect.right-bounds.x)/cell));
                var bottom:int=Math.min(data.height,Math.ceil((rect.bottom-bounds.y)/cell));
                for(var x:int=left;x<right;x++) for(var y:int=top;y<bottom;y++) {
                    var wx:Number=bounds.x+(x+0.5)*cell,wy:Number=bounds.y+(y+0.5)*cell;
                    var edge:Number=Math.min(wx-rect.left,rect.right-wx,wy-rect.top,rect.bottom-wy);
                    if(edge<0) continue;
                    var weight:Number=zone.feather>0?Math.min(1,edge/zone.feather):1;
                    weight=weight*weight*(3-2*weight);
                    var value:int=Math.min(background.getPixel(x,y)&255,int(shade*(1-darkness*weight*(1-zone.factor))));
                    background.setPixel(x,y,(value<<16)|(value<<8)|value);
                }
            }
            backgroundKey=signature;
        }
        private function makeLight(light:Object):BitmapData {
            var radius:Number=Number(light.radius);
            var side:int=Math.ceil(radius*2/cell)+1;
            var root:Sprite=new Sprite(),glow:Sprite=new Sprite(),mask:Sprite=new Sprite();
            var matrix:Matrix=new Matrix(); matrix.createGradientBox(radius*2/cell,radius*2/cell);
            glow.graphics.beginGradientFill(GradientType.RADIAL,[0xFFFFFF,0xFFFFFF,0],[1,1,1],[0,45,255],matrix);
            glow.graphics.drawRect(0,0,side,side);glow.graphics.endFill();
            mask.graphics.beginFill(0xFFFFFF);
            var cone:Number=Number(light.cone),center:Number=Number(light.angle);
            var full:Boolean=cone>=Math.PI*2-0.01;
            var start:Number=full?0:center-cone/2;
            var count:int=Math.max(24,Math.ceil(cone/(Math.PI/90)));
            if(!full) mask.graphics.moveTo(radius/cell,radius/cell);
            for(var i:int=0;i<=count;i++) {
                var angle:Number=start+cone*i/count;
                var distance:Number=traceRay(light.x,light.y,Math.cos(angle),Math.sin(angle),radius);
                var px:Number=(radius+Math.cos(angle)*distance)/cell;
                var py:Number=(radius+Math.sin(angle)*distance)/cell;
                if(i==0 && full) mask.graphics.moveTo(px,py);else mask.graphics.lineTo(px,py);
            }
            if(!full) mask.graphics.lineTo(radius/cell,radius/cell);
            mask.graphics.endFill();root.addChild(glow);root.addChild(mask);glow.mask=mask;
            var result:BitmapData=new BitmapData(side,side,false,0);
            result.draw(root);return result;
        }
        public function traceRay(sx:Number,sy:Number,dx:Number,dy:Number,radius:Number):Number {
            var cx:int=Math.floor(sx/40),cy:int=Math.floor(sy/40);
            var stepX:int=dx<0?-1:1,stepY:int=dy<0?-1:1;
            var nextX:Number=Math.abs(dx)<0.00001?1e20:((cx+(stepX>0?1:0))*40-sx)/dx;
            var nextY:Number=Math.abs(dy)<0.00001?1e20:((cy+(stepY>0?1:0))*40-sy)/dy;
            var deltaX:Number=Math.abs(dx)<0.00001?1e20:Math.abs(40/dx);
            var deltaY:Number=Math.abs(dy)<0.00001?1e20:Math.abs(40/dy);
            var distance:Number=0,opacity:Number=0;
            while(distance<radius) {
                if(nextX<nextY) {distance=nextX;nextX+=deltaX;cx+=stepX;}
                else {distance=nextY;nextY+=deltaY;cy+=stepY;}
                if(distance>=radius) break;
                if(cx<0||cy<0||cx>=loc.spaceX||cy>=loc.spaceY) return Math.max(0,distance);
                opacity+=Math.max(0,Number(loc.space[cx][cy].opac));
                if(opacity>=0.99) return Math.max(0,distance-1);
            }
            return radius;
        }
        public function sample(x:Number,y:Number):Number {
            if(data==null || !bounds.contains(x,y)) return 1;
            var value:uint=data.getPixel(Math.min(data.width-1,Math.max(0,int((x-bounds.x)/cell))),
                Math.min(data.height-1,Math.max(0,int((y-bounds.y)/cell))));
            return Math.max((value>>16)&255,(value>>8)&255,value&255)/255;
        }
    }
}
