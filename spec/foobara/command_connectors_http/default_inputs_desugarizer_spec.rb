RSpec.describe Foobara::CommandConnectors::Http::Desugarizers::DefaultInputs do
  let(:command_class) do
    stub_class(:SomeCommand, Foobara::Command) do
      inputs do
        foo :string, :required
        bar :string, :required
      end
      result :duck

      def execute = inputs
    end
  end

  let(:some_foo) { "Fooooooo" }

  let(:command_connector) { Foobara::CommandConnectors::Http.new }
  let(:response) { command_connector.run(path:, query_string:) }
  let(:query_string) { "bar=barvalue" }
  let(:path) { "/run/#{command_class.full_command_name}" }

  context "when using a proc" do
    before do
      foo = some_foo
      command_connector.connect(command_class, request: { default: { foo: -> { foo } } })
    end

    it "sets the input to the expected value" do
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to eq("bar" => "barvalue", "foo" => "Fooooooo")
    end
  end

  context "when using direct value" do
    before do
      foo = some_foo
      command_connector.connect(command_class, request: { default: { foo: } })
    end

    it "sets the input to the expected value" do
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to eq("bar" => "barvalue", "foo" => "Fooooooo")
    end

    it "makes changes in the manifest" do
      manifest = command_connector.foobara_manifest

      expect(manifest[:command][:SomeCommand][:inputs_type][:defaults][:foo]).to eq("Fooooooo")
      expect(manifest[:command][:SomeCommand][:inputs_type][:required]).to eq([:bar])
    end
  end
end
