package fe.unit {
    import fe.weapon.Bullet;
    import fe.loc.Box;
    public class Unit {
        public function Unit(id:String=null,level:Number=100,node:XML=null,saved:Object=null) {}
        public function step():* {}
        public function damage(amount:Number,kind:int,bullet:Bullet=null,critical:Boolean=false):Number {return 0;}
        public function udarBullet(bullet:Bullet,mode:int=0):int {return 0;}
        public function udarUnit(unit:Unit,multiplier:Number=1):Boolean {return false;}
        public function udarBox(box:Box):int {return 0;}
        public function die(kind:int=0):* {}
        public function setNull(reset:Boolean=false):* {}
    }
}
