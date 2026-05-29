use v6.d;
use ORM::ActiveRecord::Model;

unit module Factory::Test::AR;

class FactoryUser is Model is export {
  method table-name { 'factory_users' }

  submethod BUILD {
    self.validate: 'fname', { :presence };
    self.validate: 'lname', { :presence };
  }
}

class FactoryPost is Model is export {
  method table-name { 'factory_posts' }

  submethod BUILD {
    self.validate: 'title', { :presence };
    self.belongs-to: factory_user => True;
  }
}

sub publish-globals is export {
  GLOBAL::<FactoryUser> := FactoryUser;
  GLOBAL::<FactoryPost> := FactoryPost;
}
