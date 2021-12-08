import Prim "mo:⛔";

actor {
  var count = 0;
  public shared func inc() : async () {
    count := count + 1;
    Prim.debugPrint("count = " # debug_show(count));
  };

  system func heartbeat() : async () {
    if (count < 10) {
      Prim.debugPrint("heartbeat");
      ignore inc();
    }
  };
};
