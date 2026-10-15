package lad {
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;

    /** Deterministic fixture styles and ambient-only dark pockets; no per-frame randomness. */
    public final class LadAtmosphere {
        public var config:Object={version:1,autoDarkZones:true,lamps:[],darkZones:[]};
        public var settings:Object;
        public function LadAtmosphere() { bind(null); }
        public function load():void {
            var file:File=File.applicationDirectory.resolvePath("mods/LightAndDarkness/atmosphere.json");
            if(!file.exists) return;
            var stream:FileStream=new FileStream();
            try {
                stream.open(file,FileMode.READ);
                var value:Object=JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
                if(value.version!=1 || !(value.lamps is Array) || !(value.darkZones is Array)) throw new Error("invalid atmosphere configuration");
                config=value;
                LadLog.write("ATMOSPHERE_CONFIG loaded");
            } catch(error:*) {LadLog.write("ATMOSPHERE_CONFIG_REJECT "+error+"; built-in defaults retained");}
            finally {try {stream.close();} catch(ignored:*) {}}
        }
        public function bind(value:Object):void {
            value=value || {};
            settings={flicker:value.flicker!==false,brightness:clamp(value.brightness,0.25,1.5,1),
                speed:clamp(value.speed,0.25,2,1),darkZones:value.darkZones!==false,
                darkness:clamp(value.darkness,0,1,1),projectiles:value.projectiles!==false,
                projectileBrightness:clamp(value.projectileBrightness,0.25,1.5,1)};
        }
        public static function clamp(value:*,low:Number,high:Number,fallback:Number):Number {
            return value==null || !isFinite(Number(value))?fallback:Math.max(low,Math.min(high,Number(value)));
        }
        public static function seed(value:String):uint {
            var result:uint=2166136261;
            for(var i:int=0;i<value.length;i++) {result^=value.charCodeAt(i);result+=(result<<1)+(result<<4)+(result<<7)+(result<<8)+(result<<24);}
            return result;
        }
        public function style(value:Object,identity:String,type:String,land:String,room:String):Object {
            var code:uint=seed(identity),pick:int=code%100;
            var mode:String=pick<14?"slow":pick<24?"fast":pick<32?"burst":"steady";
            var defaults:Object={mode:mode,brightness:[0.35,0.65,1][(code>>>8)%3],frequency:frequency(mode)};
            var source:String="auto-v1";
            for each(var rule:Object in config.lamps) if(matches(rule,land,room) && (!rule.type || rule.type==type) && (!rule.key || identity.substr(identity.lastIndexOf("#")+1)==rule.key)) {
                defaults=rule;source="rule-"+seed(JSON.stringify(rule)).toString(16);break;
            }
            // A changed authored rule updates an existing save once. Unchanged rules
            // preserve repairs, rather than making the same lamp faulty on every load.
            if(value==null || (value.source!=null && value.source!=source)) value=defaults;
            mode=String(value.mode);
            if(["steady","slow","fast","burst"].indexOf(mode)<0) mode="steady";
            return {mode:mode,brightness:clamp(value.brightness,0.1,1,0.65),frequency:clamp(value.frequency,0.1,4,frequency(mode)),source:source};
        }
        private static function frequency(mode:String):Number {return mode=="slow"?0.45:mode=="fast"?2:mode=="burst"?0.8:1;}
        private static function matches(rule:Object,land:String,room:String):Boolean {
            return rule!=null && (!rule.land || rule.land==land) && (!rule.room || rule.room==room);
        }
        public function wave(style:Object,time:Number,phase:Number=0):Number {
            if(!settings.flicker || style.mode=="steady") return 1;
            var cycles:Number=time*Math.min(6,style.frequency*settings.speed)+phase;
            var p:Number=cycles-Math.floor(cycles);
            if(style.mode=="slow") return 0.08+0.92*(0.5+0.5*Math.cos(p*Math.PI*2));
            if(style.mode=="fast") return p<0.62?1:p<0.78?0.08:0.4;
            // Several short failed starts followed by a long dim interval.
            return p<0.12?1:p<0.20?0.04:p<0.28?0.8:p<0.36?0.04:p<0.52?1:0.04;
        }
        public function power(lamp:Object,time:Number):Number {
            if(lamp.state.hp<=0 || !lamp.state.on || !lamp.powered) return 0;
            return Math.min(1.5,settings.brightness*lamp.state.atmosphere.brightness*
                wave(lamp.state.atmosphere,time,lamp.phase)*(0.6+0.4*lamp.state.hp/40));
        }
        public function zones(loc:*,identity:String):Array {
            var result:Array=[],width:Number=loc.spaceX*40,height:Number=loc.spaceY*40;
            // Indoor pockets are repeatable world rectangles, independent of camera and discovery order.
            if(config.autoDarkZones!==false && !loc.sky) {
                for(var x:int=0;x<width;x+=560) for(var y:int=0;y<height;y+=560) {
                    var n:uint=seed(identity+":"+x+":"+y);
                    if(n%100>=38 || result.length>=128) continue;
                    result.push({x:x+40,y:y+40,width:440,height:440,feather:110,factor:0.08});
                }
            }
            for each(var zone:Object in config.darkZones) {
                if(!matches(zone,String(loc.land.act.id),String(loc.id)) || result.length>=128) continue;
                if(!isFinite(Number(zone.x)) || !isFinite(Number(zone.y)) || Number(zone.width)<=0 || Number(zone.height)<=0) continue;
                result.push({x:clamp(zone.x,-width,width,0),y:clamp(zone.y,-height,height,0),
                    width:clamp(zone.width,1,width*2,440),height:clamp(zone.height,1,height*2,440),
                    feather:clamp(zone.feather,0,1000,80),factor:clamp(zone.factor,0,1,0.05)});
            }
            return result;
        }
    }
}
