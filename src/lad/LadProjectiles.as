package lad {
    import flash.geom.Rectangle;
    import flash.utils.Dictionary;
    import flash.utils.getDefinitionByName;

    /** Observes native objects without changing their lifetime, damage or display. */
    public final class LadProjectiles {
        public static const MAX_TRACKED:int=192;
        public static const MAX_PULSES:int=96;
        public static const MAX_LIGHTS:int=24;
        public var clock:Number=0;
        public var captured:int=0;
        public var dropped:int=0;
        public var scanCount:int=0;
        private var world:*,loc:*;
        private var records:Array=[];
        private var known:Dictionary=new Dictionary(true);
        private var pulses:Array=[];
        private var serial:int=0;
        private var emitters:Class;
        private var grafon:Class;
        private var bulletClass:Class;
        private var view:Rectangle;
        public function LadProjectiles() {}
        public function bind(w:*,location:*):void {
            if(loc===location) return;
            clear();world=w;loc=location;
            bulletClass=getDefinitionByName("fe.weapon.Bullet") as Class;
            emitters=getDefinitionByName("fe.graph.Emitter") as Class;
            grafon=getDefinitionByName("fe.graph.Grafon") as Class;
        }
        public function clear():void {
            records=[];pulses=[];known=new Dictionary(true);loc=null;world=null;clock=0;view=null;
        }
        public function setView(value:Rectangle):void {view=value.clone();}
        public function get trackedCount():int {return records.length;}
        public function get pulseCount():int {return pulses.length;}
        public function observe(o:*):void {
            if(!loc || !o || o.loc!==loc || !o.vis || known[o]) return;
            var bullet:Boolean=o is bulletClass;
            if(!bullet && !("blitData" in o && "mliv" in o)) return;
            known[o]=true;
            // Part is fully initialized before addObj; negative cache prevents a
            // shower of smoke/blood/shells from being reclassified every tick.
            if(!bullet && partProfile(o)==null) return;
            if(records.length>=MAX_TRACKED) {dropped++;return;}
            // Bullet constructor has not yet received Weapon.setBullet fields here.
            records.push({o:o,id:++serial,bullet:bullet,p:null,started:false,hit:false,
                x:Number(o.X),y:Number(o.Y),lastTick:-1});captured++;
        }
        private function partProfile(o:*):Object {
            if(!emitters || !grafon) return null;
            for each(var id:String in LadProjectileProfiles.EMITTER_IDS) {
                var emitter:*=emitters["arr"][id];
                if(!emitter) continue;
                if((o.vClass && emitter.visClass===o.vClass) ||
                    (o.blitData && emitter.blit && grafon["spriteLists"][emitter.blit]===o.blitData))
                    {
                        // These native emitters share a sprite sheet. Preserve
                        // their public blend/scale clues without replaying emit.
                        if(id=="expl") {
                            if(o.vis.blendMode=="screen") id="fireexpl";
                            else if(Math.abs(o.vis.scaleX)>=1.5) id="ttexpl";
                        } else if(id=="plaexpl" && Math.abs(o.vis.scaleX)>=1.5) id="ttplaexpl";
                        return LadProjectileProfiles.emitter(id);
                    }
            }
            return null;
        }
        public function advance():void {
            if(!loc) return;
            clock+=1/30;
            for(var i:int=pulses.length-1;i>=0;i--) if(pulses[i].until<=clock) pulses.splice(i,1);
            // Fallback discovers objects already present when the mod/scene was enabled.
            var object:*=loc.firstObj;scanCount=0;
            while(object && scanCount<2048) {observe(object);object=object.nobj;scanCount++;}
            capture();
        }
        public function capture():Boolean {
            if(!loc) return false;
            var changed:Boolean=false;
            for(var i:int=records.length-1;i>=0;i--) {
                var r:Object=records[i],o:*=r.o;
                if(o.loc!==loc) {records.splice(i,1);continue;}
                if(!r.started) {
                    r.p=r.bullet?LadProjectileProfiles.bullet(o):partProfile(o);
                    r.started=true;
                    if(!r.p) {records.splice(i,1);continue;}
                    if(!r.bullet) {
                        if(o.otklad>0) {if(!o.in_chain) records.splice(i,1);else r.started=false;continue;}
                        flash(Number(o.X),Number(o.Y),r.p.radius,r.p.power,r.p.color,r.p.life,"blast");
                        records.splice(i,1);changed=true;continue;
                    }
                    if(r.p.muzzle && !o.isExpl) {
                        flash(Number(o.begx),Number(o.begy),Math.min(110,r.p.radius+25),r.p.power,r.p.color,0.07,"muzzle");
                        changed=true;
                    }
                }
                var p:Object=r.p;
                var x:Number=Number(o.X),y:Number=Number(o.Y);
                var moved:Boolean=Math.abs(x-r.x)+Math.abs(y-r.y)>0.5;
                var tick:int=int(clock*30+0.5);
                if(p.flight && (moved || r.lastTick!=tick) && !o.isExpl && (!o.babah || !r.hit)) {
                    var sx:Number=p.beam?Number(o.begx):r.x;
                    var sy:Number=p.beam?Number(o.begy):r.y;
                    trail(r.id,sx,sy,x,y,p);
                    changed=true;
                }
                if(!r.hit && (o.isExpl || o.babah)) {
                    r.hit=true;
                    if(o.isExpl) {
                        // Visible parent gives a fallback when native particles are disabled.
                        // Gas/acid and weapon-specific no-light explosions remain dark.
                        var explosion:Object=explosionProfile(o,p);
                        if(explosion) {
                            var size:Number=Math.min(360,Math.max(explosion.radius,Number(o.explRadius)*1.25));
                            impact(x,y,r.x,r.y,size,explosion.power,explosion.color,explosion.life,"blast");changed=true;
                        }
                    } else if(o.tilehit || (o.parr && o.parr.length>0)) {
                        impact(x,y,r.x,r.y,p.impact,p.power,p.color,p.life,"impact");changed=true;
                    }
                }
                r.x=x;r.y=y;r.lastTick=tick;
                if(!o.in_chain || o.liv<=0 || o.off || r.hit) records.splice(i,1);
            }
            return changed;
        }
        private function explosionProfile(o:*,fallback:Object):Object {
            var visual:String=o.weap?String(o.weap.visexpl):"";
            if(visual=="sparkle") visual=Number(o.inWater)>0?"explw":"sparkleexpl";
            if(visual && visual!="null" && visual!="undefined") return LadProjectileProfiles.emitter(visual);
            var damage:int=int(o.tipDamage);
            if([3,4,6,8,10,11,15].indexOf(damage)<0) return null;
            if(damage==3 && Number(o.inWater)>0) return null;
            var id:String=damage==3?"fireexpl":damage==6?"plaexpl":damage==8?"impexpl":damage==10?"acidexpl":damage==11?"iceexpl":damage==15?"balefire":Number(o.inWater)>0?"explw":"expl";
            return LadProjectileProfiles.emitter(id);
        }
        private function trail(id:int,sx:Number,sy:Number,x:Number,y:Number,p:Object):void {
            var dx:Number=x-sx,dy:Number=y-sy,length:Number=Math.sqrt(dx*dx+dy*dy);
            if(!isFinite(length)) return;
            if(p.beam && view) {
                var clipped:Array=clip(sx,sy,dx,dy,p.radius);
                if(!clipped) return;
                x=sx+dx*clipped[1];y=sy+dy*clipped[1];
                sx+=dx*clipped[0];sy+=dy*clipped[0];
                dx=x-sx;dy=y-sy;length=Math.sqrt(dx*dx+dy*dy);
            }
            // Beam segments sample the true native endpoint, never an extrapolated shot.
            var count:int=Math.min(p.beam?16:4,Math.max(1,Math.ceil(length/(p.beam?100:65))));
            for(var n:int=0;n<count;n++) {
                var t:Number=(n+0.5)/count;
                var px:Number=sx+dx*t,py:Number=sy+dy*t;
                // Pellets/flame at the same place share a glow instead of adding
                // dozens of identical lights and washing the entire room white.
                if(free(px,py)) put("trail:"+int(px/48)+":"+int(py/48)+":"+uint(p.color),px,py,p.radius,p.power*(p.beam?0.8:0.65),p.color,p.tail);
            }
        }
        private function clip(sx:Number,sy:Number,dx:Number,dy:Number,radius:Number):Array {
            var rect:Rectangle=view.clone();rect.inflate(radius,radius);
            var start:Number=0,end:Number=1;
            var origins:Array=[sx,sy],deltas:Array=[dx,dy],low:Array=[rect.left,rect.top],high:Array=[rect.right,rect.bottom];
            for(var i:int=0;i<2;i++) {
                if(Math.abs(deltas[i])<0.00001) {if(origins[i]<low[i] || origins[i]>high[i]) return null;}
                else {
                    var a:Number=(low[i]-origins[i])/deltas[i],b:Number=(high[i]-origins[i])/deltas[i];
                    start=Math.max(start,Math.min(a,b));end=Math.min(end,Math.max(a,b));
                    if(start>end) return null;
                }
            }
            return [start,end];
        }
        private function free(x:Number,y:Number):Boolean {
            if(!isFinite(x) || !isFinite(y)) return false;
            var tx:int=Math.floor(x/40),ty:int=Math.floor(y/40);
            return tx>=0 && ty>=0 && tx<loc.spaceX && ty<loc.spaceY && Number(loc.space[tx][ty].opac)<0.99;
        }
        private function impact(x:Number,y:Number,previousX:Number,previousY:Number,radius:Number,power:Number,color:uint,life:Number,kind:String):void {
            // Native collision endpoints can be inside a wall; never start a light there.
            if(!free(x,y)) {
                var dx:Number=previousX-x,dy:Number=previousY-y,len:Number=Math.sqrt(dx*dx+dy*dy);
                if(len<=0 || !isFinite(len)) return;
                for(var n:int=1;n<=20;n++) {
                    var t:Number=Math.min(len,n*4)/len;
                    if(free(x+dx*t,y+dy*t)) {x+=dx*t;y+=dy*t;break;}
                }
            }
            flash(x,y,radius,power,color,life,kind);
        }
        private function flash(x:Number,y:Number,radius:Number,power:Number,color:uint,life:Number,kind:String):void {
            if(!free(x,y) || radius<=0) return;
            // A shotgun volley and an explosion's particle cluster share one local flash.
            var id:String=kind+":"+int(x/80)+":"+int(y/80);
            if(kind=="blast") for each(var old:Object in pulses) {
                if(old.id.indexOf("blast:")==0 && old.until>clock && Math.abs(old.x-x)<=70 && Math.abs(old.y-y)<=70) {id=old.id;break;}
            }
            put(id,x,y,radius,power,color,life);
        }
        private function put(id:String,x:Number,y:Number,radius:Number,power:Number,color:uint,life:Number):void {
            if(!isFinite(radius) || !isFinite(power) || life<=0) return;
            var value:Object=null;
            for each(var entry:Object in pulses) if(entry.id==id) {value=entry;break;}
            if(!value) {
                if(pulses.length>=MAX_PULSES) {pulses.shift();dropped++;}
                value={id:id};pulses.push(value);
            } else if(id.indexOf("blast:")==0 && value.until>clock) {
                // The same detonation can emit a generic flash plus a coloured
                // special effect. The stronger/larger effect owns its colour.
                if(value.power>power || (value.power==power && value.radius>radius)) color=value.color;
                radius=Math.max(radius,value.radius);power=Math.max(power,value.power);
                life=Math.max(life,value.until-clock);
            }
            value.x=x;value.y=y;value.radius=Math.min(360,Math.max(1,radius));
            value.power=Math.min(1.1,Math.max(0,power));value.color=color;
            value.born=clock;value.life=life;value.until=clock+life;
        }
        public function lights(view:Rectangle,brightness:Number=1):Array {
            var result:Array=[];
            for each(var p:Object in pulses) {
                if(p.until<=clock || !view.intersects(new Rectangle(p.x-p.radius,p.y-p.radius,2*p.radius,2*p.radius))) continue;
                var remaining:Number=Math.max(0,Math.min(1,(p.until-clock)/p.life));
                var power:Number=p.power*remaining*remaining*brightness;
                result.push({id:"projectile:"+p.id,x:p.x,y:p.y,radius:p.radius,color:p.color,power:power,angle:0,cone:Math.PI*2,transient:true});
            }
            if(result.length>MAX_LIGHTS) {
                var cx:Number=view.x+view.width/2,cy:Number=view.y+view.height/2;
                result.sort(function(a:Object,b:Object):Number {
                    var ar:Number=a.power*a.radius/(80+Math.abs(a.x-cx)+Math.abs(a.y-cy));
                    var br:Number=b.power*b.radius/(80+Math.abs(b.x-cx)+Math.abs(b.y-cy));
                    return br-ar;
                });
                result.length=MAX_LIGHTS;
            }
            return result;
        }
    }
}
