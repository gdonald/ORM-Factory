use ORM::ActiveRecord::Schema::Migration;

class CreateFactoryUsers is Migration {
  method up {
    self.create-table: 'factory_users', [
      fname => { :string, limit => 32 },
      lname => { :string, limit => 32 },
      email => { :string, limit => 128 },
      role  => { :string, limit => 32 },
    ];
    self.add-timestamps: 'factory_users';
  }

  method down {
    self.drop-table: 'factory_users';
  }
}
