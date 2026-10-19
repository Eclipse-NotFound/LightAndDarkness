package lad {
    /** Typed snapshot of the native tile properties that affect illumination. */
    public final class LadTileState {
        public var opacity:Number;
        public var back:String;
        public var rear:Boolean;
        public var front:String;
        public function LadTileState(opacity:Number,back:String,rear:Boolean,front:String) {
            this.opacity=opacity;this.back=back;this.rear=rear;this.front=front;
        }
    }
}
