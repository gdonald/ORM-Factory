use v6.d;

unit module Factory::Test::Models;

class User is export {
  has Str  $.fname is rw;
  has Str  $.lname is rw;
  has Str  $.email is rw;
  has Str  $.role  is rw;
  has Bool $.saved is rw = False;
  method save-bang { $!saved = True; self }
}

class Post is export {
  has Str  $.title  is rw;
  has Str  $.body   is rw;
  has User $.author is rw;
  has Bool $.saved  is rw = False;
  method save-bang { $!saved = True; self }
}

class Comment is export {
  has Str $.body         is rw;
  has     $.commentable  is rw;
  has     $.author       is rw;
  has Bool $.saved       is rw = False;
  method save-bang { $!saved = True; self }
}

sub publish-globals is export {
  GLOBAL::<User>    := User;
  GLOBAL::<Post>    := Post;
  GLOBAL::<Comment> := Comment;
}
