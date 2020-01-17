import Prim "mo:prim";
import Prelude "prelude.mo";

module {
  public func abs(x : Int) : Nat = Prim.abs x;

  public func add(x : Int, y : Int) : Int {
    x + y;
  };

  public func toText(x : Int) : Text {
    if (x == 0) {
      return "0";
    };

    let isNegative = x < 0;
    var int = if isNegative (-x) else x;

    var text = "";
    let base = 10;

    while (int > 0) {
      let rem = int % base;
      text := (switch (rem) {
        case 0 "0";
        case 1 "1";
        case 2 "2";
        case 3 "3";
        case 4 "4";
        case 5 "5";
        case 6 "6";
        case 7 "7";
        case 8 "8";
        case 9 "9";
        case _ Prelude.unreachable();
      }) # text;
      int := int / base;
    };

    return if isNegative ("-" # text) else text;
  };

  public func fromInt8 (x : Int8):  Int = Prim.int8ToInt x;
  public func fromInt16(x : Int16): Int = Prim.int16ToInt x;
  public func fromInt32(x : Int32): Int = Prim.int32ToInt x;
  public func fromInt64(x : Int64): Int = Prim.int64ToInt x;
  public func toInt8 (x : Int) : Int8   = Prim.intToInt8  x;
  public func toInt16(x : Int) : Int16  = Prim.intToInt16 x;
  public func toInt32(x : Int) : Int32  = Prim.intToInt32 x;
  public func toInt64(x : Int) : Int64  = Prim.intToInt64 x;
}
