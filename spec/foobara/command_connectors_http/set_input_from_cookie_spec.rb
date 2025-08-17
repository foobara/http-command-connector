RSpec.describe Foobara::CommandConnectors::Http::SetInputFromCookie do
  let(:command_class) do
    stub_class(:SomeCommand, Foobara::Command) do
      inputs foo: :string, bar: :string
      result :duck

      def execute
        inputs
      end
    end
  end

  let(:request_mutator) do
    described_class.for(:foo, "foo_cookie")
  end

  let(:command_connector) { Foobara::CommandConnectors::Http.new }
  let(:response) { command_connector.run(path:, query_string:, cookies:) }
  let(:query_string) { "bar=barvalue" }
  let(:path) { "/run/#{command_class.full_command_name}" }
  let(:cookies) do
    { "foo_cookie" => "foovalue" }
  end

  before do
    command_connector.connect(command_class, request_mutators: request_mutator)
  end

  it "moves the cookie to an input" do
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)).to eq("bar" => "barvalue", "foo" => "foovalue")
  end

  it "makes changes in the manifest" do
    manifest = command_connector.foobara_manifest

    expect(manifest[:command][:SomeCommand][:inputs_type]).to eq(
      type: :attributes,
      element_type_declarations: {
        bar: :string
      }
    )
  end
end
