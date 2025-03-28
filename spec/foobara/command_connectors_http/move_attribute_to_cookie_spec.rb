RSpec.describe Foobara::CommandConnectors::Http::MoveAttributeToCookie do
  let(:command_class) do
    stub_class(:SomeCommand, Foobara::Command) do
      result foo: :string, bar: :string
      def execute
        { foo: "foo value", bar: "bar value" }
      end
    end
  end

  let(:response_mutator) do
    described_class.for(:foo, "foo_cookie", httponly: true)
  end

  let(:command_connector) { Foobara::CommandConnectors::Http.new }
  let(:response) { command_connector.run(path: "/run/#{command_class.full_command_name}") }

  before do
    command_connector.connect(command_class, response_mutators: response_mutator)
  end

  it "moves the attribute to a cookie" do
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)).to eq("bar" => "bar value")

    cookie = response.cookies.first

    expect(cookie.name).to eq("foo_cookie")
    expect(cookie.value).to eq("foo value")
    expect(cookie.httponly).to be true
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
