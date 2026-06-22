use v6.d;
use ORM::ActiveRecord::Model;

unit module Factory::Test::AR;

class User is Model is export {
  method table-name { 'users' }

  submethod BUILD {
    self.validate: 'fname', { :presence };
    self.validate: 'lname', { :presence };
  }
}

class Post is Model is export {
  method table-name { 'posts' }

  submethod BUILD {
    self.validate: 'title', { :presence };
    self.belongs-to: user => True;
  }
}

class Order is Model is export {
  method table-name { 'orders' }

  submethod BUILD {
    self.enum: 'status', { pending => 0, shipped => 1, delivered => 2 };
  }
}

sub publish-globals is export {
  GLOBAL::<User>  := User;
  GLOBAL::<Post>  := Post;
  GLOBAL::<Order> := Order;
}
