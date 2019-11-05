require 'lite_spec_helper'
require 'mongo'

require 'base64'

describe Mongo::ClientEncryption do
  require_libmongocrypt

  let(:key_vault_db) { SpecConfig.instance.test_db }
  let(:key_vault_coll) { 'keys' }
  let(:key_vault_namespace) { "#{key_vault_db}.#{key_vault_coll}" }

  let(:client) do
    ClientRegistry.instance.new_local_client(
      [SpecConfig.instance.addresses.first]
    )
  end

  let(:kms_providers) do
    {
      local: {
        key: Base64.encode64("ru\xfe\x00" * 24)
      }
    }
  end

  let(:client_encryption) do
    described_class.new(client, {
      key_vault_namespace: key_vault_namespace,
      kms_providers: kms_providers
    })
  end

  describe '#initialize' do
    let(:client) { new_local_client_nmio([SpecConfig.instance.addresses.first]) }

    context 'with nil key_vault_namespace' do
      let(:key_vault_namespace) { nil }

      it 'raises an exception' do
        expect do
          client_encryption
        end.to raise_error(ArgumentError, /:key_vault_namespace option cannot be nil/)
      end
    end

    context 'with invalid key_vault_namespace' do
      let(:key_vault_namespace) { 'three.word.namespace' }

      it 'raises an exception' do
        expect do
          client_encryption
        end.to raise_error(ArgumentError, /invalid key vault namespace/)
      end
    end

    context 'with invalid KMS provider information' do
      let(:kms_providers) { { random_key: {} } }

      it 'raises an exception' do
        expect do
          client_encryption
        end.to raise_error(ArgumentError, /kms_providers option must have one of the following keys/)
      end
    end

    context 'with valid options' do
      after do
        client_encryption.close
      end

      it 'creates a ClientEncryption object' do
        expect do
          client_encryption
        end.not_to raise_error
      end
    end
  end

  describe '#create_data_key' do

    let(:result) { client_encryption.create_data_key }

    after do
      client_encryption.close
    end

    it 'returns a binary uuid object' do
      expect(result).to be_a_kind_of(BSON::Binary)
      expect(result.type).to eq(:uuid)

      # make sure that the key actually exists in the DB
      expect(client.use(key_vault_db)[key_vault_coll].find(_id: result).count).to eq(1)
    end
  end
end
