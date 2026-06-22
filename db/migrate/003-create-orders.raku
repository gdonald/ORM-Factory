use ORM::ActiveRecord::Schema::Migration;

class CreateOrders is Migration {
  method up {
    self.create-table: 'orders', [
      status => { :integer },
    ];
    self.add-timestamps: 'orders';
  }

  method down {
    self.drop-table: 'orders';
  }
}
