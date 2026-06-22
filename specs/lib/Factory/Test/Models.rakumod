use v6.d;

unit module Factory::Test::Models;

# Plain test doubles shared by the DB-agnostic specs and their t/ mirrors. They
# live here (one definition each) rather than inline in every spec because
# behave's parallel runner loads all spec files into one parent process to
# discover examples; a package-scoped `our class User` repeated across files
# would redeclare during that pass. Each class is the union of the attributes
# its consumers touch, typed so the "default value is the type object" checks
# (e.g. an unset role is `Str`, an unset author is `User`) still hold.

class User is export {
  has Str  $.fname    is rw;
  has Str  $.lname    is rw;
  has Str  $.email    is rw;
  has Str  $.role     is rw;
  has Str  $.status   is rw;
  has Str  $.greeting is rw;
  has Bool $.flag     is rw;
  has      $.via      is rw;
  has      @.events;
  has Bool $.saved    is rw = False;
  method save-bang { $!saved = True; self }
}

class Post is export {
  has Str  $.title  is rw;
  has Str  $.body   is rw;
  has User $.author is rw;
  has Bool $.saved  is rw = False;
  method save-bang { $!saved = True; self }
}

class Person is export {
  has Str  $.fname is rw;
  has Str  $.lname is rw;
  has Str  $.email is rw;
  has Str  $.role  is rw;
  has Bool $.flag  is rw;
  has Bool $.saved is rw = False;
  method save-bang { $!saved = True; self }
}

class Profile is export {
  has User $.user    is rw;
  has Str  $.tagline is rw;
  has Str  $.fname   is rw;
  has Str  $.email   is rw;
  has Str  $.nick    is rw;
  has Bool $.saved   is rw = False;
  method save-bang { $!saved = True; self }
}

class Comment is export {
  has Str $.body        is rw;
  has     $.commentable is rw;
  has     $.author      is rw;
  has Bool $.saved      is rw = False;
  method save-bang { $!saved = True; self }
}

sub publish-globals is export {
  GLOBAL::<User>    := User;
  GLOBAL::<Post>    := Post;
  GLOBAL::<Person>  := Person;
  GLOBAL::<Profile> := Profile;
  GLOBAL::<Comment> := Comment;
}
