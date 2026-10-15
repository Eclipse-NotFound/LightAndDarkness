package {
    import flash.display.Sprite;
    import flash.display.StageQuality;
    import flash.events.Event;
    import lad.LadLightField;
    public class LightEdgeProbe extends Sprite {
        public function LightEdgeProbe() {addEventListener(Event.ADDED_TO_STAGE,run);}
        private function run(event:Event):void {
            removeEventListener(Event.ADDED_TO_STAGE,run);stage.quality=StageQuality.HIGH;
            new LightEdgeChecks(LadLightField).run();
        }
    }
}
