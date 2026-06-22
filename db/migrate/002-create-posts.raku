use ORM::ActiveRecord::Schema::Migration;

class CreatePosts is Migration {
  method up {
    self.create-table: 'posts', [
      user => { :reference },
      title        => { :string, limit => 80 },
      body         => { :text },
    ];
    self.add-timestamps: 'posts';
  }

  method down {
    self.drop-table: 'posts';
  }
}
