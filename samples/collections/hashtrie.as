/*
 Hash Tries in ActorScript
 -------------------------

 Functional maps (and sets) whose representation is "canonical", and
 history independent.

  See this POPL 1989 paper (Section 6):
    - "Incremental computation via function caching", Pugh & Teitelbaum.
    - https://dl.acm.org/citation.cfm?id=75305
    - Public copy here: http://matthewhammer.org/courses/csci7000-s17/readings/Pugh89.pdf

 By contrast, other usual functional representations of maps (AVL
 Trees, Red-Black Trees) do not enjoy history independence, and are
 each more complex to implement (e.g., each requires "rebalancing";
 these trees never do).

 */

// Done:
//
//  - (hacky) type definition; XXX: need real sum types to clean it up
//  - find operation
//  - insert operation
//  - remove operation
//  - replace operation (remove+insert via a single traversal)
//  - basic encoding of sets, and some set operations
//  - basic tests (and primitive debugging) for set operations

// TODO-Matthew:
//
//  - write trie operations that operate over pairs of tries:
//    for set union, difference and intersection.
//
//  - (more) regression tests for everything that is below
//
//  - handle hash collisions gracefully
//
//  - iterator objects, for use in 'for ... in ...' patterns

// TEMP: A "bit string" as a linked list of bits:
type Bits = ?(Bool, Bits);

// TODO: Replace this definition WordX, for some X, once we have these types in AS.
type Hash = Bits;
//type Hash = Word16;
//type Hash = Word8;

// Uniform depth assumption:
//
// We make a simplifying assumption, for now: All defined paths in the
// trie have a uniform length, the same as the number of bits of a
// hash, starting at the LSB, that we use for indexing.
//
// - If the number is too low, our expected O(log n) bounds become
//   expected O(n).
//
// - If the number is too high, we waste constant factors for
//   representing small sets/maps.
//
// TODO: Make this more robust by making this number adaptive for each
// path, and based on the content of the trie along that path.
//
let HASH_BITS = 4;

// XXX: See AST-42
type Node<K,V> = {
  left:Trie<K,V>;
  right:Trie<K,V>;
  key:?K;
  val:?V
};
type Trie<K,V> = ?Node<K,V>;

/* See AST-42 (sum types); we want this type definition instead:

// Use a sum type (AST-42)
type Trie<K,V>     = { #leaf : LeafNode<K,V>; #bin : BinNode<K,V>; #empty };
type BinNode<K,V>  = { left:Trie<K,V>; right:Trie<K,V> };
type LeafNode<K,V> = { key:K; val:V };

*/

// XXX: until AST-42:
func isNull<X>(x : ?X) : Bool {
  switch x {
    case null { true  };
    case (?_) { false };
  };
};

// XXX: until AST-42:
func assertIsNull<X>(x : ?X) {
  switch x {
    case null { assert(true)  };
    case (?_) { assert(false) };
  };
};

// XXX: until AST-42:
func makeEmpty<K,V>() : Trie<K,V>
  = null;

// Note: More general version of this operation below, which tests for
// "deep emptiness" (subtrees that have branching structure, but no
// leaves; these can result from naive filtering operations, for
// instance).
//
// // XXX: until AST-42:
// func isEmpty<K,V>(t:Trie<K,V>) : Bool {
//   switch t {
//     case null { true  };
//     case (?_) { false };
//   };
// };

// XXX: until AST-42:
func assertIsEmpty<K,V>(t : Trie<K,V>) {
  switch t {
    case null { assert(true)  };
    case (?_) { assert(false) };
  };
};

// XXX: until AST-42:
func makeBin<K,V>(l:Trie<K,V>, r:Trie<K,V>) : Trie<K,V>  {
  ?(new {left=l; right=r; key=null; val=null })
};

// XXX: until AST-42:
func isBin<K,V>(t:Trie<K,V>) : Bool {
  switch t {
  case null { false };
  case (?t_) {
         switch (t_.key) {
         case null { true };
         case _ { false };
         };
       };
  }
};

// XXX: until AST-42:
func makeLeaf<K,V>(k:K, v:V) : Trie<K,V> {
  ?(new {left=null; right=null; key=?k; val=?v })
};

// XXX: until AST-42:
func matchLeaf<K,V>(t:Trie<K,V>) : ?(K,V) {
  switch t {
  case null { null };
  case (?t_) {
         switch (t_.key, t_.val) {
         case (?k,?v) ?(k,v);
         case (_)     null;
         }
       };
  }
};

// XXX: until AST-42:
func isLeaf<K,V>(t:Trie<K,V>) : Bool {
  switch t {
  case null { false };
  case (?t_) {
         switch (t_.key) {
         case null { false };
         case _ { true };
         }
       };
  }
};
// XXX: until AST-42:
func assertIsBin<K,V>(t : Trie<K,V>) {
  switch t {
    case null { assert(false) };
    case (?n) {
      assertIsNull<K>(n.key);
      assertIsNull<V>(n.val);
   };
  }
};

// XXX: until AST-42:
func getLeafKey<K,V>(t : Node<K,V>) : K {
  assertIsNull<Node<K,V>>(t.left);
  assertIsNull<Node<K,V>>(t.right);
  switch (t.key) {
    case (?k) { k };
    case null { getLeafKey<K,V>(t) };
  }
};

// XXX: this helper is an ugly hack; we need real sum types to avoid it, I think:
func getLeafVal<K,V>(t : Node<K,V>) : ?V {
  assertIsNull<Node<K,V>>(t.left);
  assertIsNull<Node<K,V>>(t.right);
  t.val
};

// TODO: Replace with bitwise operations on Words, once we have each of those in AS.
// For now, we encode hashes as lists of booleans.
func getHashBit(h:Hash, pos:Nat) : Bool {
  switch h {
  case null {
         // XXX: Should be an error case; it shouldn't happen in our tests if we set them up right.
         false
       };
  case (?(b, h_)) {
         if (pos == 0) { b }
         else { getHashBit(h_, pos-1) }
       };
  }
};

// part of "public interface":
func empty<K,V>() : Trie<K,V> = makeEmpty<K,V>();

// helper function for constructing new paths of uniform length
func buildNewPath<K,V>(bitpos:Nat, k:K, k_hash:Hash, ov:?V) : Trie<K,V> {
  func rec(bitpos:Nat) : Trie<K,V> {
    if ( bitpos < HASH_BITS ) {
      // create new bin node for this bit of the hash
      let path = rec(bitpos+1);
      let bit = getHashBit(k_hash, bitpos);
      if (not bit) {
        ?(new {left=path; right=null; key=null; val=null})
      }
      else {
        ?(new {left=null; right=path; key=null; val=null})
      }
    } else {
      // create new leaf for (k,v) pair
      ?(new {left=null; right=null; key=?k; val=ov })
    }
  };
  rec(bitpos)
};

// replace the given key's value option with the given one, returning the previous one
func replace<K,V>(t : Trie<K,V>, k:K, k_hash:Hash, v:?V) : (Trie<K,V>, ?V) {
  // For `bitpos` in 0..HASH_BITS, walk the given trie and locate the given value `x`, if it exists.
  func rec(t : Trie<K,V>, bitpos:Nat) : (Trie<K,V>, ?V) {
    if ( bitpos < HASH_BITS ) {
      switch t {
      case null { (buildNewPath<K,V>(bitpos, k, k_hash, v), null) };
      case (?n) {
        assertIsBin<K,V>(t);
        let bit = getHashBit(k_hash, bitpos);
        // rebuild either the left or right path with the inserted (k,v) pair
        if (not bit) {
          let (l, v_) = rec(n.left, bitpos+1);
          (?(new {left=l; right=n.right; key=null; val=null }), v_)
        }
        else {
          let (r, v_) = rec(n.right, bitpos+1);
          (?(new {left=n.left; right=r; key=null; val=null }), v_)
        }
      };
    }
    } else {
      // No more walking; we should be at a leaf now, by construction invariants.
      switch t {
        case null { (buildNewPath<K,V>(bitpos, k, k_hash, v), null) };
        case (?l) {
           // TODO: Permit hash collisions by walking a list/array of KV pairs in each leaf:
           (?(new{left=null;right=null;key=?k;val=v}), l.val)
        };
      }
    }
  };
  rec(t, 0)
};

// insert the given key's value in the trie; return the new trie
func insert<K,V>(t : Trie<K,V>, k:K, k_hash:Hash, v:V) : (Trie<K,V>, ?V) {
  replace<K,V>(t, k, k_hash, ?v)
};

// remove the given key's value in the trie; return the new trie
func remove<K,V>(t : Trie<K,V>, k:K, k_hash:Hash) : (Trie<K,V>, ?V) {
  replace<K,V>(t, k, k_hash, null)
};

// find the given key's value in the trie, or return null if nonexistent
func find<K,V>(t : Trie<K,V>, k:K, k_hash:Hash, keq:(K,K) -> Bool) : ?V {
  // For `bitpos` in 0..HASH_BITS, walk the given trie and locate the given value `x`, if it exists.
  func rec(t : Trie<K,V>, bitpos:Nat) : ?V {
    if ( bitpos < HASH_BITS ) {
      switch t {
      case null {
        // the trie may be "sparse" along paths leading to no keys, and may end early.
        null
      };
      case (?n) {
        assertIsBin<K,V>(t);
        let bit = getHashBit(k_hash, bitpos);
        if (not bit) { rec(n.left,  bitpos+1) }
        else         { rec(n.right, bitpos+1) }
        };
      }
    } else {
      // No more walking; we should be at a leaf now, by construction invariants.
      switch t {
        case null { null };
        case (?l) {
           // TODO: Permit hash collisions by walking a list/array of KV pairs in each leaf:
           if (keq(getLeafKey<K,V>(l), k)) {
             getLeafVal<K,V>(l)
           } else {
             null
           }
        };
      }
    }
  };
  rec(t, 0)
};

// merge tries, preferring the right trie where there are collisions
// in common keys. note: the `disj` operation generalizes this `merge`
// operation in various ways, and does not (in general) loose
// information; this operation is a simpler, special case.
func merge<K,V>(tl:Trie<K,V>, tr:Trie<K,V>) : Trie<K,V> {
  switch (tl, tr) {
    case (null, _) { return tr };
    case (_, null) { return tl };
    case (?nl,?nr) {
    switch (isBin<K,V>(tl), isBin<K,V>(tr)) {
    case (true, true) {
           let t0 = merge<K,V>(nl.left, nr.left);
           let t1 = merge<K,V>(nl.right, nr.right);
           makeBin<K,V>(t0, t1)
         };
    case (false, true) {
           assert(false);
           // XXX impossible, until we lift uniform depth assumption
           tr
         };
    case (true, false) {
           assert(false);
           // XXX impossible, until we lift uniform depth assumption
           tr
         };
    case (false, false) {
           /// XXX: handle hash collisions here.
           tr
         };
      }
   };
  }
};

// The key-value pairs of the final trie consists of those pairs of
// the left trie whose keys are not present in the right trie; the
// values of the right trie are irrelevant.
func diff<K,V,W>(tl:Trie<K,V>, tr:Trie<K,W>, keq:(K,K)->Bool) : Trie<K,V> {
  func rec(tl:Trie<K,V>, tr:Trie<K,W>) : Trie<K,V> {
    switch (tl, tr) {
    case (null, _) { return makeEmpty<K,V>() };
    case (_, null) { return tl };
    case (?nl,?nr) {
    switch (isBin<K,V>(tl), isBin<K,W>(tr)) {
    case (true, true) {
           let t0 = rec(nl.left, nr.left);
           let t1 = rec(nl.right, nr.right);
           makeBin<K,V>(t0, t1)
         };
    case (false, true) {
           assert(false);
           // XXX impossible, until we lift uniform depth assumption
           tl
         };
    case (true, false) {
           assert(false);
           // XXX impossible, until we lift uniform depth assumption
           tl
         };
    case (false, false) {
           /// XXX: handle hash collisions here.
           switch (nl.key, nr.key) {
             case (?kl, ?kr) {
               if (keq(kl, kr)) {
                 makeEmpty<K,V>();
               } else {
                 tl
               }};
             // XXX impossible, and unnecessary with AST-42.
             case _ { tl }
           }
         };
      }
   };
  }};
  rec(tl, tr)
};

// This operation generalizes the notion of "set union" to finite maps.
// Produces a "disjunctive image" of the two tries, where the values of
// matching keys are combined with the given binary operator.
func disj<K,V,W,X>(tl:Trie<K,V>, tr:Trie<K,W>, keq:(K,K)->Bool, vbin:(?V,?W)->X) : Trie<K,X> {
  func recL(t:Trie<K,V>) : Trie<K,X> {
    switch t {
      case (null) null;
      case (? n) {
      switch (matchLeaf<K,V>(t)) {
        case (?(k,v)) { makeLeaf<K,X>(k, vbin(?v, null)) };
        case _ { makeBin<K,X>(recL(n.left), recL(n.right)) }
      }
    };
  }};
  func recR(t:Trie<K,W>) : Trie<K,X> {
    switch t {
      case (null) null;
      case (? n) {
      switch (matchLeaf<K,W>(t)) {
        case (?(k,w)) { makeLeaf<K,X>(k, vbin(null, ?w)) };
        case _ { makeBin<K,X>(recR(n.left), recR(n.right)) }
      }
    };
  }};
  func rec(tl:Trie<K,V>, tr:Trie<K,W>) : Trie<K,X> {
    switch (tl, tr) {
    // empty-empty terminates early, all other cases do not.
    case (null, null) { makeEmpty<K,X>() };
    case (null, _   ) { recR(tr) };
    case (_,    null) { recL(tl) };
    case (? nl, ? nr) {
    switch (isBin<K,V>(tl), isBin<K,W>(tr)) {
    case (true, true) {
           let t0 = rec(nl.left, nr.left);
           let t1 = rec(nl.right, nr.right);
           makeBin<K,X>(t0, t1)
         };
    case (false, true) {
           assert(false);
           // XXX impossible, until we lift uniform depth assumption
           makeEmpty<K,X>()
         };
    case (true, false) {
           assert(false);
           // XXX impossible, until we lift uniform depth assumption
           makeEmpty<K,X>()
         };
    case (false, false) {
           assert(isLeaf<K,V>(tl));
           assert(isLeaf<K,W>(tr));
           switch (nl.key, nl.val, nr.key, nr.val) {
             // leaf-leaf case
             case (?kl, ?vl, ?kr, ?vr) {
               if (keq(kl, kr)) {
                 makeLeaf<K,X>(kl, vbin(?vl, ?vr));
               } else {
                 // XXX: handle hash collisions here.
                 makeEmpty<K,X>()
               }
             };
             // XXX impossible, and unnecessary with AST-42.
             case _ { makeEmpty<K,X>() };
           }
         };
      }
   };
  }};
  rec(tl, tr)
};

// This operation generalizes the notion of "set intersection" to
// finite maps.  Produces a "conjuctive image" of the two tries, where
// the values of matching keys are combined with the given binary
// operator, and unmatched key-value pairrs are not present in the output.
func conj<K,V,W,X>(tl:Trie<K,V>, tr:Trie<K,W>, keq:(K,K)->Bool, vbin:(V,W)->X) : Trie<K,X> {
  func rec(tl:Trie<K,V>, tr:Trie<K,W>) : Trie<K,X> {
    switch (tl, tr) {
      case (null, null) { return makeEmpty<K,X>() };
      case (null, ? nr) { return makeEmpty<K,X>() };
      case (? nl, null) { return makeEmpty<K,X>() };
      case (? nl, ? nr) {
      switch (isBin<K,V>(tl), isBin<K,W>(tr)) {
      case (true, true) {
             let t0 = rec(nl.left, nr.left);
             let t1 = rec(nl.right, nr.right);
             makeBin<K,X>(t0, t1)
           };
      case (false, true) {
             assert(false);
             // XXX impossible, until we lift uniform depth assumption
             makeEmpty<K,X>()
           };
      case (true, false) {
             assert(false);
             // XXX impossible, until we lift uniform depth assumption
             makeEmpty<K,X>()
           };
      case (false, false) {
             assert(isLeaf<K,V>(tl));
             assert(isLeaf<K,W>(tr));
             switch (nl.key, nl.val, nr.key, nr.val) {
               // leaf-leaf case
             case (?kl, ?vl, ?kr, ?vr) {
                    if (keq(kl, kr)) {
                      makeLeaf<K,X>(kl, vbin(vl, vr));
                    } else {
                      // XXX: handle hash collisions here.
                      makeEmpty<K,X>()
                    }
                  };
             // XXX impossible, and unnecessary with AST-42.
             case _ { makeEmpty<K,X>() };
             }
           };
          }
         }
    }};
  rec(tl, tr)
};

func foldUp<K,V,X>(t:Trie<K,V>, bin:(X,X)->X, leaf:(K,V)->X, empty:X) : X {
  func rec(t:Trie<K,V>) : X {
    switch t {
    case (null) { empty };
    case (?n) {
           switch (matchLeaf<K,V>(t)) {
           case (?(k,v)) { leaf(k,v) };
           case null { bin(rec(n.left), rec(n.right)) };
           }
    };
    }};
  rec(t)
};

// Test for "deep emptiness": subtrees that have branching structure,
// but no leaves.  These can result from naive filtering operations;
// filter uses this function to avoid creating such subtrees.
func isEmpty<K,V>(t:Trie<K,V>) : Bool {
  func rec(t:Trie<K,V>) : Bool {
    switch t {
    case (null) { true };
    case (?n) {
           switch (matchLeaf<K,V>(t)) {
           case (?(k,v)) { false };
           case null { rec(n.left) and rec(n.right) };
           }
         };
    }
  };
  rec(t)
};

func filter<K,V,X>(t:Trie<K,V>, f:(K,V)->Bool) : Trie<K,V> {
  func rec(t:Trie<K,V>) : Trie<K,V> {
    switch t {
    case (null) { null };
    case (?n) {
           switch (matchLeaf<K,V>(t)) {
           case (?(k,v)) {
                  // XXX-Typechecker:
                  //  This version of the next line gives _really_
                  //  strange type errors, and no parse errors.
                  // if f(k,v) {
                  if (f(k,v)) {
                    makeLeaf<K,V>(k,v)
                  } else {
                    null
                  }
                };
           case null {
                  let l = rec(n.left);
                  let r = rec(n.right);
                  switch (isEmpty<K,V>(l),isEmpty<K,V>(r)) {
                    case (true,  true)  null;
                    case (false, true)  r;
                    case (true,  false) l;
                    case (false, false) makeBin<K,V>(l, r);
                  }
                };
           }
         };
    }
  };
  rec(t)
};

// Test for equality, but naively, based on structure.
// Does not attempt to remove "junk" in the tree;
// For instance, a "smarter" approach would equate
//   `#bin{left=#empty;right=#empty}`
// with
//   `#empty`.
// We do not observe that equality here.
func equalStructure<K,V>(
  tl:Trie<K,V>,
  tr:Trie<K,V>,
  keq:(K,K)->Bool,
  veq:(V,V)->Bool
) : Bool {
  func rec(tl:Trie<K,V>, tr:Trie<K,V>) : Bool {
    switch (tl, tr) {
    case (null, null) { true };
    case (?nl, ?nr) {
           switch (matchLeaf<K,V>(tl), matchLeaf<K,V>(tr)) {
           case (?(kl,vl), ?(kr,vr)) { keq(kl,kr) and veq(vl,vr) };
           case (null,     null)     { rec(nl.left, nr.left)
                                       and rec(nl.right, nr.right) };
           case _ { false }
           }
    };
    }};
  rec(tl, tr)
};

///////////////////////////////////////////////////////////////////////

/*
 Sets are partial maps from element type to unit type,
 i.e., the partial map represents the set with its domain.
*/

// TODO-Matthew:
//
// - for now, we pass a hash value each time we pass an element value;
//   in the future, we might avoid passing element hashes with each element in the API;
//   related to: https://dfinity.atlassian.net/browse/AST-32
//
// - similarly, we pass an equality function when we do some operations.
//   in the future, we might avoid this via https://dfinity.atlassian.net/browse/AST-32
//

type Set<T> = Trie<T,()>;

func setEmpty<T>():Set<T> =
  empty<T,()>();

func setInsert<T>(s:Set<T>, x:T, xh:Hash):Set<T> = {
  let (s2, _) = insert<T,()>(s, x, xh, ());
  s2
};

func setRemove<T>(s:Set<T>, x:T, xh:Hash):Set<T> = {
  let (s2, _) = remove<T,()>(s, x, xh);
  s2
};

func setEq<T>(s1:Set<T>, s2:Set<T>, eq:(T,T)->Bool):Bool {
  // XXX: Todo: use a smarter check
  equalStructure<T,()>(s1, s2, eq, unitEq)
};

func setCard<T>(s:Set<T>) : Nat {
  foldUp<T,(),Nat>
  (s,
   func(n:Nat,m:Nat):Nat{n+m},
   func(_:T,_:()):Nat{1},
   0)
};

func setMem<T>(s:Set<T>, x:T, xh:Hash, eq:(T,T)->Bool):Bool {
  switch (find<T,()>(s, x, xh, eq)) {
  case null { false };
  case (?_) { true };
  }
};

func setUnion<T>(s1:Set<T>, s2:Set<T>):Set<T> {
  let s3 = merge<T,()>(s1, s2);
  s3
};

func setDiff<T>(s1:Set<T>, s2:Set<T>, eq:(T,T)->Bool):Set<T> {
  let s3 = diff<T,(),()>(s1, s2, eq);
  s3
};

func setIntersect<T>(s1:Set<T>, s2:Set<T>, eq:(T,T)->Bool):Set<T> {
  let noop : ((),())->(()) = func (_:(),_:()):(())=();
  let s3 = conj<T,(),(),()>(s1, s2, eq, noop);
  s3
};

////////////////////////////////////////////////////////////////////

func setPrint(s:Set<Nat>) {
  func rec(s:Set<Nat>, ind:Nat, bits:Hash) {
    func indPrint(i:Nat) {
      if (i == 0) { } else { print "| "; indPrint(i-1) }
    };
    func bitsPrintRev(bits:Bits) {
      switch bits {
        case null { print "" };
        case (?(bit,bits_)) {
               bitsPrintRev(bits_);
               if bit { print "1R." }
               else   { print "0L." }
             }
      }
    };
    switch s {
    case null {
           //indPrint(ind);
           //bitsPrintRev(bits);
           //print "(null)\n";
         };
    case (?n) {
           switch (n.key) {
           case null {
                  //indPrint(ind);
                  //bitsPrintRev(bits);
                  //print "bin \n";
                  rec(n.right, ind+1, ?(true, bits));
                  rec(n.left,  ind+1, ?(false,bits));
                  //bitsPrintRev(bits);
                  //print ")\n"
                };
           case (?k) {
                  //indPrint(ind);
                  bitsPrintRev(bits);
                  print "(leaf ";
                  printInt k;
                  print ")\n";
                };
           }
         };
    }
  };
  rec(s, 0, null);
};

////////////////////////////////////////////////////////////////////////////////

func natEq(n:Nat,m:Nat):Bool{ n == m};
func unitEq (_:(),_:()):Bool{ true };

func setInsertDb(s:Set<Nat>, x:Nat, xh:Hash):Set<Nat> = {
  print "  setInsert(";
  printInt x;
  print ")";
  let r = setInsert<Nat>(s,x,xh);
  print ";\n";
  setPrint(r);
  r
};

func setMemDb(s:Set<Nat>, sname:Text, x:Nat, xh:Hash):Bool = {
  print "  setMem(";
  print sname;
  print ", ";
  printInt x;
  print ")";
  let b = setMem<Nat>(s,x,xh,natEq);
  if b { print " = true" } else { print " = false" };
  print ";\n";
  b
};

func setUnionDb(s1:Set<Nat>, s1name:Text, s2:Set<Nat>, s2name:Text):Set<Nat> = {
  print "  setUnion(";
  print s1name;
  print ", ";
  print s2name;
  print ")";
  // also: test that merge agrees with disj:
  let r1 = setUnion<Nat>(s1, s2);
  let r2 = disj<Nat,(),(),()>(s1, s2, natEq, func (_:?(),_:?()):(())=());
  assert(equalStructure<Nat,()>(r1, r2, natEq, unitEq));
  print ";\n";
  setPrint(r1);
  print "=========\n";
  setPrint(r2);
  r1
};

func setIntersectDb(s1:Set<Nat>, s1name:Text, s2:Set<Nat>, s2name:Text):Set<Nat> = {
  print "  setIntersect(";
  print s1name;
  print ", ";
  print s2name;
  print ")";
  let r = setIntersect<Nat>(s1, s2, natEq);
  print ";\n";
  setPrint(r);
  r
};

/////////////////////////////////////////////////////////////////////////////////

let hash_0 = ?(false,?(false,?(false,?(false, null))));
let hash_1 = ?(false,?(false,?(false,?(true,  null))));
let hash_2 = ?(false,?(false,?(true, ?(false, null))));
let hash_3 = ?(false,?(false,?(true, ?(true,  null))));
let hash_4 = ?(false,?(true, ?(false,?(false, null))));
let hash_5 = ?(false,?(true, ?(false,?(true,  null))));
let hash_6 = ?(false,?(true, ?(true, ?(false, null))));
let hash_7 = ?(false,?(true, ?(true, ?(true,  null))));
let hash_8 = ?(true, ?(false,?(false,?(false, null))));

print "inserting...\n";
// Insert numbers [0..8] into the set, using their bits as their hashes:
let s0 : Set<Nat> = setEmpty<Nat>();
assert(setCard<Nat>(s0) == 0);

let s1 : Set<Nat> = setInsertDb(s0, 0, hash_0);
assert(setCard<Nat>(s1) == 1);

let s2 : Set<Nat> = setInsertDb(s1, 1, hash_1);
assert(setCard<Nat>(s2) == 2);

let s3 : Set<Nat> = setInsertDb(s2, 2, hash_2);
assert(setCard<Nat>(s3) == 3);

let s4 : Set<Nat> = setInsertDb(s3, 3, hash_3);
assert(setCard<Nat>(s4) == 4);

let s5 : Set<Nat> = setInsertDb(s4, 4, hash_4);
assert(setCard<Nat>(s5) == 5);

let s6 : Set<Nat> = setInsertDb(s5, 5, hash_5);
assert(setCard<Nat>(s6) == 6);

let s7 : Set<Nat> = setInsertDb(s6, 6, hash_6);
assert(setCard<Nat>(s7) == 7);

let s8 : Set<Nat> = setInsertDb(s7, 7, hash_7);
assert(setCard<Nat>(s8) == 8);

let s9 : Set<Nat> = setInsertDb(s8, 8, hash_8);
assert(setCard<Nat>(s9) == 9);
print "done.\n";

print "unioning...\n";
let s1s2 : Set<Nat> = setUnionDb(s1, "s1", s2, "s2");
let s2s1 : Set<Nat> = setUnionDb(s2, "s2", s1, "s1");
let s3s2 : Set<Nat> = setUnionDb(s3, "s3", s2, "s2");
let s4s2 : Set<Nat> = setUnionDb(s4, "s4", s2, "s2");
let s1s5 : Set<Nat> = setUnionDb(s1, "s1", s5, "s5");
let s0s2 : Set<Nat> = setUnionDb(s0, "s0", s2, "s2");
print "done.\n";

print "intersecting...\n";
let s3is6 : Set<Nat> = setIntersectDb(s3, "s3", s6, "s6");
let s2is1 : Set<Nat> = setIntersectDb(s2, "s2", s1, "s1");
print "done.\n";


print "testing membership...\n";

// Element 0: Test memberships of each set defined above for element 0
assert( not( setMemDb(s0, "s0", 0, hash_0 ) ));
assert( setMemDb(s1, "s1", 0, hash_0 ) );
assert( setMemDb(s2, "s2", 0, hash_0 ) );
assert( setMemDb(s3, "s3", 0, hash_0 ) );
assert( setMemDb(s4, "s4", 0, hash_0 ) );
assert( setMemDb(s5, "s5", 0, hash_0 ) );
assert( setMemDb(s6, "s6", 0, hash_0 ) );
assert( setMemDb(s7, "s7", 0, hash_0 ) );
assert( setMemDb(s8, "s8", 0, hash_0 ) );
assert( setMemDb(s9, "s9", 0, hash_0 ) );

// Element 1: Test memberships of each set defined above for element 1
assert( not(setMemDb(s0, "s0", 1, hash_1 )) );
assert( not(setMemDb(s1, "s1", 1, hash_1 )) );
assert( setMemDb(s2, "s2", 1, hash_1 ) );
assert( setMemDb(s3, "s3", 1, hash_1 ) );
assert( setMemDb(s4, "s4", 1, hash_1 ) );
assert( setMemDb(s5, "s5", 1, hash_1 ) );
assert( setMemDb(s6, "s6", 1, hash_1 ) );
assert( setMemDb(s7, "s7", 1, hash_1 ) );
assert( setMemDb(s8, "s8", 1, hash_1 ) );
assert( setMemDb(s9, "s9", 1, hash_1 ) );

// Element 2: Test memberships of each set defined above for element 2
assert( not(setMemDb(s0, "s0", 2, hash_2 )) );
assert( not(setMemDb(s1, "s1", 2, hash_2 )) );
assert( not(setMemDb(s2, "s2", 2, hash_2 )) );
assert( setMemDb(s3, "s3", 2, hash_2 ) );
assert( setMemDb(s4, "s4", 2, hash_2 ) );
assert( setMemDb(s5, "s5", 2, hash_2 ) );
assert( setMemDb(s6, "s6", 2, hash_2 ) );
assert( setMemDb(s7, "s7", 2, hash_2 ) );
assert( setMemDb(s8, "s8", 2, hash_2 ) );
assert( setMemDb(s9, "s9", 2, hash_2 ) );

// Element 3: Test memberships of each set defined above for element 3
assert( not(setMemDb(s0, "s0", 3, hash_3 )) );
assert( not(setMemDb(s1, "s1", 3, hash_3 )) );
assert( not(setMemDb(s2, "s2", 3, hash_3 )) );
assert( not(setMemDb(s3, "s3", 3, hash_3 )) );
assert( setMemDb(s4, "s4", 3, hash_3 ) );
assert( setMemDb(s5, "s5", 3, hash_3 ) );
assert( setMemDb(s6, "s6", 3, hash_3 ) );
assert( setMemDb(s7, "s7", 3, hash_3 ) );
assert( setMemDb(s8, "s8", 3, hash_3 ) );
assert( setMemDb(s9, "s9", 3, hash_3 ) );

// Element 4: Test memberships of each set defined above for element 4
assert( not(setMemDb(s0, "s0", 4, hash_4 )) );
assert( not(setMemDb(s1, "s1", 4, hash_4 )) );
assert( not(setMemDb(s2, "s2", 4, hash_4 )) );
assert( not(setMemDb(s3, "s3", 4, hash_4 )) );
assert( not(setMemDb(s4, "s4", 4, hash_4 )) );
assert( setMemDb(s5, "s5", 4, hash_4 ) );
assert( setMemDb(s6, "s6", 4, hash_4 ) );
assert( setMemDb(s7, "s7", 4, hash_4 ) );
assert( setMemDb(s8, "s8", 4, hash_4 ) );
assert( setMemDb(s9, "s9", 4, hash_4 ) );

// Element 5: Test memberships of each set defined above for element 5
assert( not(setMemDb(s0, "s0", 5, hash_5 )) );
assert( not(setMemDb(s1, "s1", 5, hash_5 )) );
assert( not(setMemDb(s2, "s2", 5, hash_5 )) );
assert( not(setMemDb(s3, "s3", 5, hash_5 )) );
assert( not(setMemDb(s4, "s4", 5, hash_5 )) );
assert( not(setMemDb(s5, "s5", 5, hash_5 )) );
assert( setMemDb(s6, "s6", 5, hash_5 ) );
assert( setMemDb(s7, "s7", 5, hash_5 ) );
assert( setMemDb(s8, "s8", 5, hash_5 ) );
assert( setMemDb(s9, "s9", 5, hash_5 ) );

// Element 6: Test memberships of each set defined above for element 6
assert( not(setMemDb(s0, "s0", 6, hash_6 )) );
assert( not(setMemDb(s1, "s1", 6, hash_6 )) );
assert( not(setMemDb(s2, "s2", 6, hash_6 )) );
assert( not(setMemDb(s3, "s3", 6, hash_6 )) );
assert( not(setMemDb(s4, "s4", 6, hash_6 )) );
assert( not(setMemDb(s5, "s5", 6, hash_6 )) );
assert( not(setMemDb(s6, "s6", 6, hash_6 )) );
assert( setMemDb(s7, "s7", 6, hash_6 ) );
assert( setMemDb(s8, "s8", 6, hash_6 ) );
assert( setMemDb(s9, "s9", 6, hash_6 ) );

// Element 7: Test memberships of each set defined above for element 7
assert( not(setMemDb(s0, "s0", 7, hash_7 )) );
assert( not(setMemDb(s1, "s1", 7, hash_7 )) );
assert( not(setMemDb(s2, "s2", 7, hash_7 )) );
assert( not(setMemDb(s3, "s3", 7, hash_7 )) );
assert( not(setMemDb(s4, "s4", 7, hash_7 )) );
assert( not(setMemDb(s5, "s5", 7, hash_7 )) );
assert( not(setMemDb(s6, "s6", 7, hash_7 )) );
assert( not(setMemDb(s7, "s7", 7, hash_7 )) );
assert( setMemDb(s8, "s8", 7, hash_7 ) );
assert( setMemDb(s9, "s9", 7, hash_7 ) );

// Element 8: Test memberships of each set defined above for element 8
assert( not(setMemDb(s0, "s0", 8, hash_8 )) );
assert( not(setMemDb(s1, "s1", 8, hash_8 )) );
assert( not(setMemDb(s2, "s2", 8, hash_8 )) );
assert( not(setMemDb(s3, "s3", 8, hash_8 )) );
assert( not(setMemDb(s4, "s4", 8, hash_8 )) );
assert( not(setMemDb(s6, "s6", 8, hash_8 )) );
assert( not(setMemDb(s6, "s6", 8, hash_8 )) );
assert( not(setMemDb(s7, "s7", 8, hash_8 )) );
assert( not(setMemDb(s8, "s8", 8, hash_8 )) );
assert( setMemDb(s9, "s9", 8, hash_8 ) );

print "done.\n";
