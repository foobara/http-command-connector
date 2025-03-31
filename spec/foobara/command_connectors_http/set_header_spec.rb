RSpec.describe Foobara::CommandConnectors::Http::SetHeader do
  let(:command_class) do
    stub_class(:SomeCommand, Foobara::Command) do
      result foo: :string, bar: :string

      def execute
        { foo: "foo value", bar: "bar value" }
      end
    end
  end

  let(:response_mutator) do
    described_class.for(:baz_header, "bazvalue")
  end

  let(:command_connector) { Foobara::CommandConnectors::Http.new }
  let(:response) { command_connector.run(path: "/run/#{command_class.full_command_name}") }

  before do
    command_connector.connect(command_class, response_mutators: response_mutator)
  end

  it "moves the attribute to a header" do
    expect(response.status).to eq(200)

    expect(JSON.parse(response.body)).to eq("foo" => "foo value", "bar" => "bar value")
    expect(response.headers["baz_header"]).to eq("bazvalue")
  end

  it "does not change the result type" do
    result_type = command_class.result_type
    expect(response_mutator.instance.result_type_from(result_type)).to be(result_type)
  end
end
