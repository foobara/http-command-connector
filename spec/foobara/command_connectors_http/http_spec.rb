RSpec.describe Foobara::CommandConnectors::Http do
  after do
    Foobara.reset_alls
  end

  let(:command_class) do
    sc = ->(*args, &block) { stub_class(*args, &block) }

    stub_class(:ComputeExponent, Foobara::Command) do
      error_klass = sc.call(:SomeRuntimeError, Foobara::RuntimeError) do
        class << self
          def context_type_declaration
            :duck
          end
        end
      end

      input_error_class = sc.call(:SomeInputError, Foobara::Value::DataError) do
        class << self
          def context_type_declaration
            :duck
          end
        end
      end

      possible_error error_klass
      possible_input_error :base, input_error_class

      inputs exponent: :integer,
             base: :integer
      result :integer

      attr_accessor :exponential

      def execute
        compute

        exponential
      end

      def compute
        self.exponential = 1

        exponent.times do
          self.exponential *= base
        end
      end
    end
  end

  let(:command_connector) do
    described_class.new(authenticator:, default_serializers:, prefix:)
  end
  let(:prefix) { nil }

  let(:command_registry) { command_connector.command_registry }

  let(:authenticator) { nil }
  let(:default_serializers) do
    [Foobara::CommandConnectors::Serializers::ErrorsSerializer,
     Foobara::CommandConnectors::Serializers::JsonSerializer]
  end
  let(:default_pre_commit_transformer) { nil }

  let(:base) { 2 }
  let(:exponent) { 3 }

  let(:response) { command_connector.run(path:, method:, headers:, query_string:, body:) }

  let(:path) { "/run/ComputeExponent" }
  let(:method) { "POST" }
  let(:headers) { { some_header_name: "some_header_value" } }
  let(:query_string) { "base=#{base}" }
  let(:body) { "{\"exponent\":#{exponent}}" }
  let(:inputs_transformers) { nil }
  let(:result_transformers) { nil }
  let(:errors_transformers) { nil }
  let(:pre_commit_transformers) { nil }
  let(:serializers) { nil }
  let(:allowed_rule) { nil }
  let(:allowed_rules) { nil }
  let(:requires_authentication) { nil }
  let(:capture_unknown_error) { false }
  let(:aggregate_entities) { nil }
  let(:atomic_entities) { nil }

  describe "#connect" do
    context "when command is in an organization" do
      let(:path) { "/run/SomeOrg/SomeDomain/SomeCommand" }
      let(:query_string) { "foo=foovalue" }
      let(:body) { "" }

      let!(:org_module) do
        stub_module :SomeOrg do
          foobara_organization!
        end
      end

      let!(:domain_module) do
        stub_module("SomeOrg::SomeDomain") do
          foobara_domain!
        end
      end

      let!(:command_class) do
        stub_module "SomeOtherOrg" do
          foobara_organization!
        end
        stub_module "SomeOtherOrg::SomeOtherDomain" do
          foobara_domain!
        end
        stub_class "SomeOtherOrg::SomeOtherDomain::SomeOtherCommand", Foobara::Command do
          inputs email: :email
        end
        stub_class "SomeOrg::SomeDomain::SomeCommand", Foobara::Command do
          description "just some command"
          depends_on SomeOtherOrg::SomeOtherDomain::SomeOtherCommand

          inputs foo: :string

          result foo: :string

          def execute
            inputs
          end
        end
      end

      it "registers the command" do
        command_connector.connect(org_module)

        exposed_commands = command_connector.all_exposed_commands
        expect(exposed_commands.size).to eq(1)
        exposed_command = exposed_commands.first

        expect(exposed_command.full_command_symbol).to eq(:"some_org::some_domain::some_command")

        transformed_command = exposed_command.transformed_command_class
        expect(transformed_command.command_class).to eq(command_class)

        command_classes = []

        command_registry.each_transformed_command_class do |klass|
          command_classes << klass
        end

        expect(command_classes).to eq([transformed_command])
        expect(command_registry.all_transformed_command_classes).to eq([transformed_command])
      end

      it "can run the command" do
        command_connector.connect(org_module)

        expect(response.status).to be(200)
      end

      context "when registering via domain" do
        before do
          command_connector.connect(domain_module)
        end

        it "registers the command" do
          transformed_commands = command_connector.all_transformed_command_classes
          expect(transformed_commands.size).to eq(1)
          expect(transformed_commands.first.command_class).to eq(command_class)
        end

        context "when generating a manifest" do
          it "includes the organization" do
            manifest = command_connector.foobara_manifest

            expect(manifest[:organization].keys).to match_array(%i[SomeOrg global_organization])
            expect(manifest[:command][:"SomeOrg::SomeDomain::SomeCommand"][:description]).to eq("just some command")
          end

          context "when generating manifest via Describe" do
            let(:request) { described_class::Request.new(path: "/manifest") }

            it "includes the organization" do
              manifest = described_class::Commands::Describe.run!(
                manifestable: command_connector,
                request:,
                detached: false
              )

              expect(manifest[:organization].keys).to match_array(%i[SomeOrg global_organization])
              expect(manifest[:command][:"SomeOrg::SomeDomain::SomeCommand"][:description]).to eq("just some command")
            end
          end
        end
      end
    end
  end

  describe "#run" do
    before do
      if allowed_rules
        command_connector.allowed_rules(allowed_rules)
      end

      if default_pre_commit_transformer
        command_connector.add_default_pre_commit_transformer(default_pre_commit_transformer)
      end

      command_connector.connect(
        command_class,
        inputs_transformers:,
        result_transformers:,
        errors_transformers:,
        serializers:,
        allowed_rule:,
        requires_authentication:,
        pre_commit_transformers:,
        capture_unknown_error:,
        aggregate_entities:,
        atomic_entities:,
        suffix:
      )
    end

    let(:suffix) { nil }

    it "runs the command" do
      expect(response.status).to be(200)
      expect(response.headers).to be_a(Hash)
      expect(response.body).to eq("8")
    end

    context "with a prefix" do
      let(:prefix) { %w[foo bar baz] }

      let(:path) { "/foo/bar/baz/run/ComputeExponent" }

      it "runs the command" do
        expect(response.status).to be(200)
        expect(response.headers).to be_a(Hash)
        expect(response.body).to eq("8")
      end

      context "when prefix has a superfluous /" do
        let(:prefix) { "foo/" }
        let(:path) { "/foo/run/ComputeExponent" }

        it "runs the command" do
          expect(response.status).to be(200)
          expect(response.headers).to be_a(Hash)
          expect(response.body).to eq("8")
        end
      end
    end

    context "with a header set via env var..." do
      stub_env_vars FOOBARA_HTTP_RESPONSE_HEADER_SOME_VAR: "some value",
                    FOOBARA_HTTP_RESPONSE_HEADER_CONTENT_TYPE: "application/json"

      it "runs the command" do
        expect(response.status).to be(200)
        expect(response.headers["content-type"]).to eq("application/json")
        expect(response.headers["some-var"]).to eq("some value")
        expect(response.body).to eq("8")
      end
    end

    context "with default transformers" do
      before do
        identity = proc { |x| x }

        command_connector.add_default_inputs_transformer(identity)
        command_connector.add_default_result_transformer(identity)
        command_connector.add_default_errors_transformer(identity)
        command_connector.add_default_pre_commit_transformer(identity)
      end

      let(:default_serializers) { Foobara::CommandConnectors::Serializers::JsonSerializer }

      it "runs the command" do
        expect(response.status).to be(200)
        expect(response.headers).to be_a(Hash)
        expect(response.body).to eq("8")
      end
    end

    context "without serializers" do
      let(:default_serializers) { nil }
      # Setting a suffix guarantees it will be transformed
      let(:suffix) { "Whatever" }
      let(:path) { "/run/ComputeExponentWhatever" }

      it "runs the command" do
        expect(response.status).to be(200)
        expect(response.headers).to be_a(Hash)
        expect(response.body).to eq(8)
      end
    end

    context "when inputs are bad" do
      let(:query_string) { "some_bad_input=10" }

      let(:default_serializers) { Foobara::CommandConnectors::Serializers::JsonSerializer }
      let(:serializers) { Foobara::CommandConnectors::Serializers::ErrorsSerializer }

      it "fails" do
        expect(response.status).to be(422)
        expect(response.headers).to be_a(Hash)

        error = JSON.parse(response.body).find { |e| e["key"] == "data.unexpected_attributes" }
        unexpected_attributes = error["context"]["unexpected_attributes"]

        expect(unexpected_attributes).to eq(["some_bad_input"])
      end
    end

    context "when unknown error" do
      let(:capture_unknown_error) { true }
      let(:default_serializers) do
        [
          Foobara::CommandConnectors::Serializers::ErrorsSerializer,
          Foobara::CommandConnectors::Serializers::JsonSerializer
        ]
      end

      before do
        command_class.define_method :execute do
          raise "kaboom!"
        end
      end

      it "fails" do
        expect(response.status).to be(500)
        expect(response.headers).to be_a(Hash)

        error = JSON.parse(response.body).find { |e| e["key"] == "runtime.unknown" }

        expect(error["message"]).to eq("kaboom!")
        expect(error["is_fatal"]).to be(true)
      end
    end

    context "with various transformers" do
      let(:query_string) { "bbaassee=#{base}" }

      let(:inputs_transformers) { [inputs_transformer] }
      let(:inputs_transformer) do
        stub_class(:RandomTransformer, Foobara::Value::Transformer) do
          def transform(inputs)
            {
              base: inputs["bbaassee"],
              exponent: inputs["exponent"]
            }
          end
        end
      end

      let(:result_transformers) { [->(result) { result * 2 }] }
      let(:errors_transformers) { [->(errors) { errors }] }

      it "runs the command" do
        expect(response.status).to be(200)
        expect(response.headers).to be_a(Hash)
        expect(response.body).to eq("16")
      end

      context "when error" do
        let(:query_string) { "foo=bar" }

        it "is not success" do
          expect(response.status).to be(422)
          expect(response.headers).to be_a(Hash)
          expect(response.body).to include("cannot_cast")
        end
      end

      context "with multiple transformers" do
        let(:identity) { ->(x) { x } }

        let(:inputs_transformers) { [identity, inputs_transformer] }
        let(:result_transformers) { [->(result) { result * 2 }, identity] }
        let(:errors_transformers) { [identity, identity] }
        let(:pre_commit_transformers) { [identity, identity] }

        it "runs the command" do
          expect(response.status).to be(200)
          expect(response.headers).to be_a(Hash)
          expect(response.body).to eq("16")
        end

        context "when error" do
          let(:query_string) { "foo=bar" }

          it "is not success" do
            expect(response.status).to be(422)
            expect(response.headers).to be_a(Hash)
            expect(response.body).to include("cannot_cast")
          end
        end
      end

      context "with transformer instance instead of class" do
        let(:inputs_transformers) { [inputs_transformer.instance] }

        it "runs the command" do
          expect(response.status).to be(200)
          expect(response.headers).to be_a(Hash)
          expect(response.body).to eq("16")
        end
      end
    end

    context "with allowed rule" do
      context "when declared with a hash" do
        let(:allowed_rule) do
          logic = proc {
            raise unless respond_to?(:base)

            base == 2
          }

          {
            logic:,
            symbol: :must_be_base_2
          }
        end

        context "when allowed" do
          it "runs the command" do
            expect(response.status).to be(200)
            expect(response.headers).to be_a(Hash)
            expect(response.body).to eq("8")
          end
        end

        context "when not allowed" do
          let(:allowed_rule) do
            logic = proc { base == 1900 }

            {
              logic:,
              symbol: :must_be_base_1900,
              explanation: proc { "Must be 1900 but was #{base}" }
            }
          end

          it "fails with 403 and relevant error" do
            expect(response.status).to be(403)
            expect(response.headers).to be_a(Hash)
            expect(JSON.parse(response.body).find { |e| e["key"] == "runtime.not_allowed" }["message"]).to eq(
              "Not allowed: Must be 1900 but was 2"
            )
          end
        end
      end

      context "when declared with the rule registry" do
        let(:allowed_rules) do
          {
            must_be_base_2: {
              logic: proc { base == 2 },
              explanation: "Must be base 2"
            },
            must_be_base_1900: {
              logic: proc { base == 1900 },
              explanation: proc { "Must be base 1900 but was #{base}" }
            }
          }
        end

        context "when allowed" do
          let(:allowed_rule) { [:must_be_base_1900, "must_be_base_2"] }

          it "runs the command" do
            expect(response.status).to be(200)
            expect(response.headers).to be_a(Hash)
            expect(response.body).to eq("8")
          end

          describe "#manifest" do
            it "contains the errors for not allowed" do
              error_manifest = command_connector.foobara_manifest[:command][:ComputeExponent][:possible_errors]

              expect(error_manifest.keys).to include("runtime.not_allowed")
            end
          end
        end

        context "when not allowed" do
          let(:allowed_rule) do
            :must_be_base_1900
          end

          it "fails with 401 and relevant error" do
            expect(command_connector.command_registry[ComputeExponent].command_class).to eq(ComputeExponent)

            expect(response.status).to be(403)
            expect(response.headers).to be_a(Hash)
            expect(JSON.parse(response.body).find { |e| e["key"] == "runtime.not_allowed" }["message"]).to eq(
              "Not allowed: Must be base 1900 but was 2"
            )
          end
        end
      end

      context "when declared with a proc" do
        context "without explanation" do
          let(:allowed_rule) do
            proc { base == 1900 }
          end

          it "fails with 401 and relevant error" do
            expect(response.status).to be(403)
            expect(response.headers).to be_a(Hash)
            expect(
              JSON.parse(response.body).find { |e| e["key"] == "runtime.not_allowed" }["message"]
            ).to match(/base == 1900/)
          end
        end
      end
    end

    context "when authentication required" do
      let(:requires_authentication) { true }

      describe "#manifest" do
        it "contains the errors for not allowed" do
          error_manifest = command_connector.foobara_manifest[:command][:ComputeExponent][:possible_errors]

          expect(error_manifest.keys).to include("runtime.unauthenticated")
        end
      end

      context "when unauthenticated" do
        let(:authenticator) do
          proc {}
        end

        it "is 401" do
          expect(response.status).to be(401)
          expect(response.headers).to be_a(Hash)
          expect(JSON.parse(response.body).map { |e| e["key"] }).to include("runtime.unauthenticated")
        end
      end

      context "when authenticated" do
        let(:authenticator) do
          # normally we would return a user but we'll just generate a pointless integer
          # to test proxying to the request
          proc { 10 }
        end

        it "is 200" do
          expect(response.status).to be(200)
          expect(response.headers).to be_a(Hash)
          expect(JSON.parse(response.body)).to eq(8)
        end
      end
    end

    context "with an entity input" do
      before do
        Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
      end

      let(:command_class) do
        user_class

        stub_class(:QueryUser, Foobara::Command) do
          inputs user: User
          result :User

          load_all

          def execute
            user
          end
        end
      end

      let(:path) { "/run/QueryUser" }
      let(:query_string) { "user=#{user_id}" }
      let(:body) { "" }

      let(:user_class) do
        stub_class(:User, Foobara::Entity) do
          attributes id: :integer,
                     name: :string,
                     ratings: [:integer],
                     junk: { type: :associative_array, value_type_declaration: :array }
          primary_key :id
        end
      end

      context "when user exists" do
        let(:user_id) do
          User.transaction do
            User.create(name: :whatever)
          end.id
        end

        let(:result_transformers) { [proc(&:attributes)] }

        it "finds the user" do
          expect(response.status).to be(200)
          expect(response.headers).to be_a(Hash)
          expect(JSON.parse(response.body)).to eq("id" => user_id, "name" => "whatever")
        end

        context "when making options call" do
          let(:method) { "OPTIONS" }

          it "finds the user" do
            expect(response.status).to be(200)
            expect(response.headers).to be_a(Hash)
            expect(response.body).to eq("")
          end
        end
      end

      context "when not found error" do
        let(:user_id) { 100 }

        it "fails" do
          expect(response.status).to be(404)
          expect(response.headers).to be_a(Hash)

          errors = JSON.parse(response.body)

          expect(errors.size).to eq(1)
          expect(errors.map { |e| e["key"] }).to include("runtime.user_not_found")
        end
      end

      context "with an association" do
        let(:point_class) do
          stub_class :Point, Foobara::Model do
            attributes x: :integer, y: :integer
          end
        end

        let(:referral_class) do
          stub_class(:Referral, Foobara::Entity) do
            attributes id: :integer, email: :email
            primary_key :id
          end
        end

        before do
          User.attributes referral: referral_class, point: point_class
        end

        context "with atomic_entities: true" do
          let(:atomic_entities) { true }

          it "includes the AtomicSerializer" do
            command_manifest = command_connector.foobara_manifest[:command][:QueryUser]
            expect(
              command_manifest[:serializers]
            ).to include("Foobara::CommandConnectors::Serializers::AtomicSerializer")
          end
        end

        context "with AtomicSerializer" do
          let(:serializers) { Foobara::CommandConnectors::Serializers::AtomicSerializer }

          context "when user exists with a referral" do
            let(:user) do
              User.transaction do
                referral = referral_class.create(email: "Some@email.com")
                User.create(name: "Some Name", referral:, ratings: [1, 2, 3], point: { x: 1, y: 2 })
              end
            end

            let(:user_id) { user.id }

            let(:referral_id) {  user.referral.id }

            it "serializes as an atom" do
              expect(response.status).to be(200)
              expect(response.headers).to be_a(Hash)
              expect(JSON.parse(response.body)).to eq(
                "id" => user_id,
                "name" => "Some Name",
                "referral" => referral_id,
                "ratings" => [1, 2, 3],
                "point" => { "x" => 1, "y" => 2 }
              )
            end
          end
        end

        context "with AggregateSerializer" do
          let(:serializers) { Foobara::CommandConnectors::Serializers::AggregateSerializer }
          let(:pre_commit_transformers) {
            Foobara::CommandConnectors::Transformers::LoadAggregatesPreCommitTransformer
          }

          context "when user exists with a referral" do
            let(:command_class) do
              user_class
              referral_class

              stub_class :QueryUser, Foobara::Command do
                inputs user: User
                result stuff: [User, Referral]

                load_all

                def execute
                  {
                    stuff: [user, user.referral]
                  }
                end
              end
            end

            let(:user) do
              User.transaction do
                referral = referral_class.create(email: "Some@email.com")
                User.create(
                  name: "Some Name",
                  referral:,
                  ratings: [1, 2, 3],
                  point: { x: 1, y: 2 },
                  junk: { [1, 2, 3] => [1, 2, 3] }
                )
              end
            end

            let(:user_id) { user.id }
            let(:referral_id) {  user.referral.id }

            it "serializes as an aggregate" do
              expect(response.status).to be(200)
              expect(response.headers).to be_a(Hash)
              expect(JSON.parse(response.body)).to eq(
                "stuff" => [
                  {
                    "id" => 1,
                    # TODO: This is kind of crazy that we can only have strings as keys. Should raise exception.
                    "junk" => { "[1, 2, 3]" => [1, 2, 3] },
                    "name" => "Some Name",
                    "point" => { "x" => 1, "y" => 2 },
                    "ratings" => [1, 2, 3],
                    "referral" => { "email" => "some@email.com", "id" => 1 }
                  },
                  {
                    "email" => "some@email.com", "id" => 1
                  }
                ]
              )
            end

            it "contains pre_commit_transformers in its manifest" do
              command_manifest = command_connector.foobara_manifest[:command][:QueryUser]
              manifest = command_manifest[:pre_commit_transformers].find { |h|
                h[:name] == "Foobara::CommandConnectors::Transformers::LoadAggregatesPreCommitTransformer"
              }
              expect(manifest).to be_a(Hash)
              expect(command_manifest[:serializers]).to include(
                "Foobara::CommandConnectors::Serializers::AggregateSerializer"
              )
            end

            context "with aggregate serializer as default serializer" do
              let(:aggregate_entities) { nil }
              let(:pre_commit_transformers) { nil }
              let(:serializers) { nil }

              let(:default_serializers) do
                [
                  Foobara::CommandConnectors::Serializers::AggregateSerializer,
                  Foobara::CommandConnectors::Serializers::ErrorsSerializer,
                  Foobara::CommandConnectors::Serializers::JsonSerializer
                ]
              end

              let(:default_pre_commit_transformer) do
                Foobara::CommandConnectors::Transformers::LoadAggregatesPreCommitTransformer
              end

              it "contains pre_commit_transformers in its manifest" do
                command_manifest = command_connector.foobara_manifest[:command][:QueryUser]
                manifest = command_manifest[:pre_commit_transformers].find { |h|
                  h[:name] == "Foobara::CommandConnectors::Transformers::LoadAggregatesPreCommitTransformer"
                }
                expect(manifest).to be_a(Hash)
                expect(command_manifest[:serializers]).to include(
                  "Foobara::CommandConnectors::Serializers::AggregateSerializer"
                )
              end

              context "when disabled via aggregate_entities: false" do
                let(:aggregate_entities) { false }

                it "does not contain pre_commit_transformers in its manifest" do
                  command_manifest = command_connector.foobara_manifest[:command][:QueryUser]
                  expect(command_manifest[:pre_commit_transformers]).to be_nil

                  expect(
                    command_manifest[:serializers]
                  ).to_not include("CommandConnectors::Serializers::AggregateSerializer")
                end
              end
            end
          end
        end

        context "with RecordStoreSerializer" do
          let(:serializers) { Foobara::CommandConnectors::Serializers::RecordStoreSerializer }
          let(:aggregate_entities) { true }

          context "when user exists with a referral" do
            let(:user) do
              User.transaction do
                referral = referral_class.create(email: "Some@email.com")
                User.create(name: "Some Name", referral:, ratings: [1, 2, 3], point: { x: 1, y: 2 })
              end
            end

            let(:user_id) { user.id }

            let(:referral_id) { user.referral.id }

            it "serializes as a record store" do
              expect(response.status).to be(200)
              expect(response.headers).to be_a(Hash)
              expect(JSON.parse(response.body)).to eq(
                "User" => {
                  "1" => {
                    "id" => 1,
                    "name" => "Some Name",
                    "referral" => 1,
                    "ratings" => [1, 2, 3],
                    "point" => { "x" => 1, "y" => 2 }
                  }
                },
                "Referral" => {
                  "1" => {
                    "id" => 1,
                    "email" => "some@email.com"
                  }
                }
              )
            end
          end
        end
      end
    end

    context "without querystring" do
      let(:query_string) { "" }
      let(:body) { "{\"exponent\":#{exponent},\"base\":#{base}}" }

      it "runs the command" do
        expect(response.status).to be(200)
        expect(response.headers).to be_a(Hash)
        expect(response.body).to eq("8")
      end
    end

    context "when handling cors stuff" do
      let(:method) { "OPTIONS" }
      let(:headers) do
        { "access-control-request-headers" => "Content-Type" }
      end

      stub_env_vars(
        "FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_ALLOW_METHODS" => "GET, POST, PUT, PATCH, DELETE, OPTIONS",
        "FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_ALLOW_HEADERS" => "*",
        "FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_EXPOSE_HEADERS" => "X-Access-Token",
        "FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_ALLOW_CREDENTIALS" => "true",
        "FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_ALLOW_ORIGIN" => "http://localhost:3000",
        "FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_MAX_AGE" => "3600"
      )

      it "returns various cors headers" do
        expect(response.headers).to eq(
          "access-control-expose-headers" => "X-Access-Token",
          "access-control-allow-credentials" => "true",
          "access-control-allow-origin" => "http://localhost:3000",
          "access-control-allow-methods" => "GET, POST, PUT, PATCH, DELETE, OPTIONS",
          "access-control-allow-headers" => "Content-Type",
          "access-control-max-age" => "3600"
        )
      end
    end

    describe "#manifest" do
      context "when various transformers" do
        let(:query_string) { "bbaassee=#{base}" }

        let(:inputs_transformers) { [inputs_transformer] }
        let(:inputs_transformer) do
          stub_class "SomeTransformer", Foobara::TypeDeclarations::TypedTransformer do
            from bbaassee: :string,
                 exponent: :string
            to base: :integer,
               exponent: :integer

            def transform(inputs)
              inputs = inputs.transform_keys(&:to_sym)

              {
                base: inputs[:bbaassee],
                exponent: inputs[:exponent]
              }
            end
          end
        end

        let(:result_transformers) { [result_transformer] }
        let(:result_transformer) do
          stub_class :SomeOtherTransformer, Foobara::TypeDeclarations::TypedTransformer do
            to answer: :string

            def transform(result)
              { answer: result.to_s }
            end
          end
        end

        it "runs the command" do
          expect(response.status).to be(200)
          expect(response.headers).to be_a(Hash)
          expect(JSON.parse(response.body)).to eq("answer" => "8")
        end

        describe "#manifest" do
          let(:manifest) { command_connector.foobara_manifest }

          it "uses types from the transformers" do
            h = manifest[:command][:ComputeExponent]

            inputs_type = h[:inputs_type]
            result_type = h[:result_type]
            error_types = h[:possible_errors]

            expect(inputs_type).to eq(
              type: :attributes,
              element_type_declarations: {
                exponent: { type: :string },
                bbaassee: { type: :string }
              }
            )
            expect(result_type).to eq(
              type: :attributes,
              element_type_declarations: {
                answer: { type: :string }
              }
            )
            expect(error_types).to eq(
              "runtime.some_runtime" => {
                category: :runtime,
                symbol: :some_runtime,
                key: "runtime.some_runtime",
                error: "SomeRuntimeError"
              },
              "data.base.some_input" => {
                path: [:base],
                category: :data,
                symbol: :some_input,
                key: "data.base.some_input",
                error: "SomeInputError",
                manually_added: true
              },
              "data.cannot_cast" => {
                category: :data,
                symbol: :cannot_cast,
                key: "data.cannot_cast",
                error: "Foobara::Value::Processor::Casting::CannotCastError",
                processor_class: "Foobara::Value::Processor::Casting",
                processor_manifest_data: {
                  casting: { cast_to: { type: :attributes,
                                        element_type_declarations: {
                                          bbaassee: { type: :string }, exponent: { type: :string }
                                        } } }
                }
              },
              "data.unexpected_attributes" => {
                category: :data,
                symbol: :unexpected_attributes,
                key: "data.unexpected_attributes",
                error: "attributes::SupportedProcessors::ElementTypeDeclarations::UnexpectedAttributesError",
                processor_class: "attributes::SupportedProcessors::ElementTypeDeclarations",
                processor_manifest_data: { element_type_declarations: { bbaassee: { type: :string },
                                                                        exponent: { type: :string } } }
              },
              "data.bbaassee.cannot_cast" => {
                path: [:bbaassee],
                category: :data,
                symbol: :cannot_cast,
                key: "data.bbaassee.cannot_cast",
                error: "Foobara::Value::Processor::Casting::CannotCastError",
                processor_manifest_data: { casting: { cast_to: { type: :string } } }
              },
              "data.exponent.cannot_cast" => {
                path: [:exponent],
                category: :data,
                symbol: :cannot_cast,
                key: "data.exponent.cannot_cast",
                error: "Foobara::Value::Processor::Casting::CannotCastError",
                processor_manifest_data: { casting: { cast_to: { type: :string } } }
              }
            )
          end
        end

        describe "#possible_errors" do
          it "contains paths matching the transformed inputs" do
            transformed_command = command_connector.transformed_command_from_name("ComputeExponent")
            expect(transformed_command.possible_errors.map(&:key).map(&:to_s)).to contain_exactly(
              "runtime.some_runtime",
              "data.base.some_input",
              "data.cannot_cast",
              "data.unexpected_attributes",
              "data.bbaassee.cannot_cast",
              "data.exponent.cannot_cast"
            )
          end
        end
      end
    end

    context "with describe path" do
      let(:path) { "/describe/ComputeExponent" }
      let(:query_string) { "" }
      let(:body) { "" }

      it "describes the command" do
        expect(response.status).to be(200)
        json = JSON.parse(response.body)
        expect(json["inputs_type"]["element_type_declarations"]["base"]["type"]).to eq("integer")
      end

      context "with describe path" do
        let(:path) { "/describe_command/ComputeExponent" }

        it "describes the command" do
          expect(response.status).to be(200)
          json = JSON.parse(response.body)
          expect(json["inputs_type"]["element_type_declarations"]["base"]["type"]).to eq("integer")
        end
      end
    end

    context "with help path" do
      let(:org_module) do
        stub_module :SomeOrg do
          foobara_organization!
        end
      end
      let(:path) { "/help" }

      let(:domain_module) do
        org_module
        stub_module("SomeOrg::SomeDomain") do
          foobara_domain!
        end
      end

      let(:another_command_class) do
        domain_module
        stub_module "SomeOtherOrg" do
          foobara_organization!
        end
        stub_module "SomeOtherOrg::SomeOtherDomain" do
          foobara_domain!
        end
        stub_class "SomeOtherOrg::SomeOtherDomain::SomeOtherCommand", Foobara::Command do
          inputs email: :email
        end
        stub_class "SomeOrg::SomeDomain::SomeCommand", Foobara::Command do
          description "just some command"
          depends_on SomeOtherOrg::SomeOtherDomain::SomeOtherCommand
        end
      end

      before do
        command_connector.connect(another_command_class)
      end

      it "gives some help" do
        expect(response.status).to be(200)
        expect(response.body).to match(/>Commands</)
      end

      context "when asking for help with a specific element" do
        let(:path) { "/help/ComputeExponent" }

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/ComputeExponent/)
        end
      end

      context "when it is something accessible through GlobalOrganization but not the connector" do
        before do
          Foobara::GlobalDomain.foobara_register_type(%w[Foo Bar whatever], :string, :downcase)
          command_connector.connect(new_command)
        end

        let(:new_command) do
          stub_class(:NewCommand, Foobara::Command) do
            inputs do
              whatever :"Foo::Bar::whatever"
              count :integer, min: 0
              log [:string]
            end
          end
        end
        let(:path) { "/help/whatever" }

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/whatever/)
        end

        context "when command" do
          let(:path) { "/help/NewCommand" }

          it "gives some help" do
            expect(response.status).to be(200)
            expect(response.body).to match(/NewCommand/)
          end
        end
      end

      context "when it doesn't exist" do
        let(:path) { "/help/nonexistent" }

        it "is not success" do
          expect(response.status).to be(404)
          expect(response.body).to match(/Not found/)
        end
      end

      context "when rendering a domain" do
        let(:path) { "/help/SomeOrg::SomeDomain" }

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/SomeOrg::SomeDomain/)
        end
      end

      context "when rendering an organization" do
        let(:path) { "/help/SomeOrg" }

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/SomeOrg/)
        end
      end

      context "when rendering an entity" do
        let(:path) { "/help/SomeOrg::SomeDomain::User" }

        let(:user_entity) do
          SomeOrg::SomeDomain.foobara_type_from_declaration(
            attributes_declaration: {
              first_name: :string,
              id: :integer
            },
            model_module: "SomeOrg::SomeDomain",
            name: "User",
            primary_key: "id",
            type: "entity"
          )
        end
        let(:some_command) do
          user_entity

          stub_class("SomeOrg::SomeDomain::SomeCommand", Foobara::Command) do
            inputs user: :User
          end
        end

        before do
          command_connector.connect(some_command)
        end

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/SomeOrg::SomeDomain::User/)
        end
      end

      context "when rendering a model" do
        let(:path) { "/help/User" }

        let(:user_model) do
          SomeOrg::SomeDomain.foobara_type_from_declaration(
            attributes_declaration: {
              first_name: :string,
              id: :integer
            },
            model_module: "SomeOrg::SomeDomain",
            name: "User",
            type: "model"
          )
        end
        let(:some_command) do
          user_model

          stub_class("SomeOrg::SomeDomain::SomeCommand", Foobara::Command) do
            inputs user: :User
          end
        end

        before do
          command_connector.connect(some_command)
        end

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/SomeOrg::SomeDomain::User/)
        end
      end

      context "when rendering an error" do
        let(:path) { "/help/SomeInputError" }

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/SomeInputError/)
        end
      end

      context "when rendering a processor" do
        let(:path) { "/help/email::Transformers::downcase" }

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/email::Transformers::downcase/)
        end
      end

      context "when rendering a processor class" do
        let(:path) { "/help/email::Transformers::Downcase" }

        it "gives some help" do
          expect(response.status).to be(200)
          expect(response.body).to match(/email::Transformers::Downcase/)
        end
      end
    end

    describe "connector manifest" do
      describe "#manifest" do
        let(:manifest) { command_connector.foobara_manifest }

        it "returns metadata about the commands" do
          expect(
            manifest[:command][:ComputeExponent][:result_type]
          ).to eq(type: :integer)
        end

        context "with an entity input" do
          before do
            Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
          end

          after do
            Foobara.reset_alls
          end

          let(:command_class) do
            user_class

            stub_class :QueryUser, Foobara::Command do
              description "Queries a user"
              inputs user: User.entity_type
              result :User
            end
          end

          let(:path) { "/run/QueryUser" }
          let(:query_string) { "user=#{user_id}" }
          let(:body) { "" }

          let(:serializers) {
            [proc(&:attributes)]
          }

          let(:user_class) do
            stub_class :User, Foobara::Entity do
              attributes id: :integer, name: :string
              primary_key :id
            end
          end

          it "returns metadata about the types referenced in the commands" do
            expect(
              manifest[:type].keys
            ).to match_array(
              %i[
                User
                array
                associative_array
                atomic_duck
                attributes
                detached_entity
                duck
                duckture
                entity
                integer
                model
                number
                string
                symbol
              ]
            )
          end

          context "with manifest path" do
            let(:query_string) { nil }
            let(:path) { "/manifest" }

            it "includes types" do
              expect(response.status).to be(200)
              json = JSON.parse(response.body)
              expect(json["type"].keys).to include("User")
              expect(json["metadata"]["url"]).to eq("/manifest")
              expect(json["metadata"]["when"]).to match(/^\d{4}-\d{2}-\d{2}/)
            end
          end

          context "with list path" do
            let(:query_string) { nil }
            let(:path) { "/list" }

            it "lists commands" do
              expect(response.status).to be(200)
              json = JSON.parse(response.body)

              expect(json).to eq([["QueryUser", nil]])
            end

            context "when verbose" do
              # TODO: would be nice to not have to do =true here...
              let(:query_string) { "verbose=true" }

              it "lists commands" do
                expect(response.status).to be(200)
                json = JSON.parse(response.body)

                expect(json).to eq([["QueryUser", "Queries a user"]])
              end
            end
          end

          context "with describe_type path" do
            let(:query_string) { nil }
            let(:path) { "/describe_type/User" }

            it "includes types" do
              expect(response.status).to be(200)
              json = JSON.parse(response.body)
              expect(json["declaration_data"]["name"]).to eq("User")
            end
          end
        end
      end
    end
  end

  describe ".default_serializers" do
    it "returns some serializers" do
      expect(described_class.default_serializers).to be_an(Array)
    end

    context "when a subclass" do
      let(:subclass) do
        stub_class :SomeSubclass, described_class
      end

      it "returns some serializers" do
        expect(subclass.default_serializers).to be_an(Array)
        expect(subclass.default_serializers).to_not be_empty
      end

      context "when subclass of a subclass" do
        let(:subsubclass) do
          stub_class :SomeSubsubclass, subclass
        end

        it "returns some serializers" do
          expect(subsubclass.default_serializers).to be_an(Array)
          expect(subsubclass.default_serializers).to_not be_empty
        end
      end
    end
  end
end
