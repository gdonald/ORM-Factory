use ORM::ActiveRecord::Schema::Migration;

class CreateFactoryPosts is Migration {
  method up {
    self.create-table: 'factory_posts', [
      factory_user => { :reference },
      title        => { :string, limit => 80 },
      body         => { :text },
    ];
    self.add-timestamps: 'factory_posts';
  }

  method down {
    self.drop-table: 'factory_posts';
  }
}
