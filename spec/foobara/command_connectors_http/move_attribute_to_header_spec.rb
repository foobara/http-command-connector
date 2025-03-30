RSpec.describe Foobara::CommandConnectors::Http::MoveAttributeToHeader do
  let(:command_class) do
    stub_class(:SomeCommand, Foobara::Command) do
      result foo: :string, bar: :string

      def execute
        { foo: "foo value", bar: "bar value" }
      end
    end
  end

  let(:response_mutator) do
    described_class.for(:foo, "foo_header")
  end

  let(:command_connector) { Foobara::CommandConnectors::Http.new }
  let(:response) { command_connector.run(path: "/run/#{command_class.full_command_name}") }

  before do
    command_connector.connect(command_class, response_mutators: response_mutator)
  end

  it "moves the attribute to a header" do
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)).to eq("bar" => "bar value")

    expect(response.headers["foo_header"]).to eq("foo value")
  end

  it "makes changes in the manifest" do
    manifest = command_connector.foobara_manifest

    expect(manifest[:command][:SomeCommand][:result_type]).to eq(
      type: :attributes,
      element_type_declarations: {
        bar: { type: :string }
      }
    )
  end
end
