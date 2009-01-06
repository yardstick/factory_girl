require(File.join(File.dirname(__FILE__), 'test_helper'))

class IntegrationTest < Test::Unit::TestCase

  def setup
    Factory.define :user, :class => 'user' do |f|
      f.first_name 'Jimi'
      f.last_name  'Hendrix'
      f.admin       false
      f.email {|a| "#{a.first_name}.#{a.last_name}@example.com".downcase }
    end

    Factory.define Post do |f|
      f.name   'Test Post'
      f.association :author, :factory => :user
    end

    Factory.define :admin, :class => User do |f|
      f.first_name 'Ben'
      f.last_name  'Stein'
      f.admin       true
      f.email { Factory.next(:email) }
    end

    Factory.sequence :email do |n|
      "somebody#{n}@example.com"
    end
  end

  def teardown
    Factory.factories.clear
  end

  context "a generated attributes hash" do

    setup do
      @attrs = Factory.attributes_for(:user, :first_name => 'Bill')
    end

    should "assign all attributes" do
      assert_equal [:admin, :email, :first_name, :last_name],
                   @attrs.keys.sort {|a, b| a.to_s <=> b.to_s }
    end

    should "correctly assign lazy, dependent attributes" do
      assert_equal "bill.hendrix@example.com", @attrs[:email]
    end

    should "override attrbutes" do
      assert_equal 'Bill', @attrs[:first_name]
    end

    should "not assign associations" do
      assert_nil Factory.attributes_for(:post)[:author]
    end

  end

  context "a built instance" do

    setup do
      @instance = Factory.build(:post)
    end

    should "not be saved" do
      assert @instance.new_record?
    end

    should "assign associations" do
      assert_kind_of User, @instance.author
    end

    should "save associations" do
      assert !@instance.author.new_record?
    end

    should "not assign both an association and its foreign key" do
      assert_equal 1, Factory.build(:post, :author_id => 1).author_id
    end

  end

  context "a created instance" do

    setup do
      @instance = Factory.create('post')
    end

    should "be saved" do
      assert !@instance.new_record?
    end

    should "assign associations" do
      assert_kind_of User, @instance.author
    end

    should "save associations" do
      assert !@instance.author.new_record?
    end

  end
  
  context "a generated mock instance" do

    setup do
      @stub = Factory.stub(:user, :first_name => 'Bill')
    end

    should "assign all attributes" do
      [:admin, :email, :first_name, :last_name].each do |attr|
        assert_not_nil @stub.send(attr)     
      end
    end

    should "correctly assign lazy, dependent attributes" do
      assert_equal "bill.hendrix@example.com", @stub.email
    end

    should "override attrbutes" do
      assert_equal 'Bill', @stub.first_name
    end

    should "not assign associations" do
      assert_nil Factory.stub(:post).author
    end

  end  

  context "an instance generated by a factory with a custom class name" do

    setup do
      @instance = Factory.create(:admin)
    end

    should "use the correct class name" do
      assert_kind_of User, @instance
    end

    should "use the correct factory definition" do
      assert @instance.admin?
    end

  end

  context "an attribute generated by a sequence" do

    setup do
      @email = Factory.attributes_for(:admin)[:email]
    end

    should "match the correct format" do
      assert_match /^somebody\d+@example\.com$/, @email
    end

    context "after the attribute has already been generated once" do

      setup do
        @another_email = Factory.attributes_for(:admin)[:email]
      end

      should "match the correct format" do
        assert_match /^somebody\d+@example\.com$/, @email
      end

      should "not be the same as the first generated value" do
        assert_not_equal @email, @another_email
      end

    end

  end

end