$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')

require "rubygems"
require "active_record"
require "factory_girl"
require "benchmark"

module DefineConstantMacros
  def define_class(path, base = Object, &block)
    namespace, class_name = *constant_path(path)
    klass = Class.new(base)
    namespace.const_set(class_name, klass)
    klass.class_eval(&block) if block_given?
    @defined_constants << path
    klass
  end

  def define_model(name, columns = {}, &block)
    model = define_class(name, ActiveRecord::Base, &block)
    create_table(model.table_name) do |table|
      columns.each do |name, type|
        table.column name, type
      end
    end
    model
  end

  def create_table(table_name, &block)
    connection = ActiveRecord::Base.connection

    begin
      connection.execute("DROP TABLE IF EXISTS #{table_name}")
      connection.create_table(table_name, &block)
      @created_tables << table_name
      connection
    rescue Exception => exception
      connection.execute("DROP TABLE IF EXISTS #{table_name}")
      raise exception
    end
  end

  def constant_path(constant_name)
    names = constant_name.split('::')
    class_name = names.pop
    namespace = names.inject(Object) { |result, name| result.const_get(name) }
    [namespace, class_name]
  end

  def default_constants
    @defined_constants ||= []
    @created_tables    ||= []
  end

  def clear_generated_constants
    @defined_constants.reverse.each do |path|
      namespace, class_name = *constant_path(path)
      namespace.send(:remove_const, class_name)
    end

    @defined_constants.clear
  end

  def clear_generated_tables
    @created_tables.each do |table_name|
      ActiveRecord::Base.
        connection.
        execute("DROP TABLE IF EXISTS #{table_name}")
    end
    @created_tables.clear
  end

  def establish_connection
    ActiveRecord::Base.establish_connection(
      :adapter  => 'sqlite3',
      :database => File.join(File.dirname(__FILE__), 'benchmark.db')
    )
  end

  def define_factories
    define_model("User", :name => :string, :admin => :boolean, :email => :string, :upper_email => :string, :login => :string)

    FactoryGirl.define do
      trait :with_login do
        login "Awesome!"
      end

      factory :user do
        name  "John"
        email { "#{name.downcase}@example.com" }
        login { email }

        factory :admin do
          factory :admin_with_traits, :traits => [:with_login]

          name "admin"
          admin true
          upper_email { email.upcase }

          factory :nested_admin do
            factory :double_nested_admin do
              factory :triple_nested_admin do
                admin true
              end
            end
          end
        end
      end
    end
  end

  def run_benchmark(text, benchmark)
    benchmark.report(text) do
      default_constants
      define_factories

      yield

      clear_generated_constants
      clear_generated_tables
      FactoryGirl.factories.clear
      FactoryGirl.sequences.clear
      FactoryGirl.traits.clear
    end
  end
end

include DefineConstantMacros

establish_connection

benchmark_count = 5_000

Benchmark.bmbm(25) do |benchmark|
  run_benchmark("build x#{benchmark_count}", benchmark) do
    benchmark_count.times { FactoryGirl.build(:admin) }
  end

  run_benchmark("trait build x#{benchmark_count}", benchmark) do
    benchmark_count.times { FactoryGirl.build(:admin_with_traits) }
  end

  run_benchmark("inline trait build x#{benchmark_count}", benchmark) do
    benchmark_count.times { FactoryGirl.build(:admin, :with_login) }
  end

  run_benchmark("deep build x#{benchmark_count}", benchmark) do
    benchmark_count.times { FactoryGirl.build(:triple_nested_admin) }
  end

  run_benchmark("overrides build x#{benchmark_count}", benchmark) do
    benchmark_count.times { FactoryGirl.build(:admin, admin: false, email: 'foo@example.com') }
  end

  run_benchmark("attributes_for x#{benchmark_count}", benchmark) do
    benchmark_count.times { FactoryGirl.attributes_for(:admin) }
  end
end
