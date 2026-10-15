package {
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.desktop.NativeApplication;
    public class LightEdgeGameProbe extends Sprite {
        private static var root:*;
        public function LightEdgeGameProbe() {}
        public static function init(main:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("remains-lad-edge-game-")!=0) return;
            root=main;root.stage.addEventListener(Event.ENTER_FRAME,ready,false,-100);
        }
        private static function ready(event:Event):void {
            var carrier:*=root.getChildByName("LightAndDarknessCarrier");
            if(!carrier || !carrier.ladAPI || !carrier.ladAPI.runtime) return;
            root.stage.removeEventListener(Event.ENTER_FRAME,ready);
            var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("edge-test.log"),FileMode.APPEND);
            f.writeUTFBytes("FROZEN_RUNTIME version="+carrier.ladAPI.version+" stageQuality="+root.stage.quality+"\n");f.close();
            new LightEdgeChecks(carrier.ladAPI.runtime.field.constructor as Class).run();
        }
    }
}
