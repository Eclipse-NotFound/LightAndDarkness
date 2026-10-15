package {
    import lad.LadRuntime;
    public class LightAndDarknessMod {
        public static const VERSION:String = "0.2.2-scene";
        public static var runtime:LadRuntime;
        public static function init(main:*):void {
            if(runtime == null) runtime = new LadRuntime(main);
        }
    }
}
