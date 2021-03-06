require 'spec_helper'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'cpi.json.erb' do
  subject { JSON.parse(template.render(manifest)) }

  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../../../../../../../../')) }
  let(:job) { release.job('openstack_cpi') }
  let(:template) { job.template('config/cpi.json') }

  let(:manifest) do
    {
      'openstack' => {
        'auth_url' => 'openstack.auth_url',
        'username' => 'openstack.username',
        'api_key' => 'openstack.api_key',
        'tenant' => 'openstack.tenant',
        'default_key_name' => 'openstack.default_key_name',
        'default_security_groups' => 'openstack.default_security_groups',
        'wait_resource_poll_interval' => 'openstack.wait_resource_poll_interval',
        'human_readable_vm_names' => false,
        'ignore_server_availability_zone' => 'openstack.ignore_server_availability_zone',
      },
      'blobstore' => {
        'provider' => 'local',
        'path' => 'blobstore-local-path',
      },
      'registry' => {
        'username' => 'registry.username',
        'password' => 'registry.password',
        'host' => 'registry.host',
      },
      'nats' => {
        'address' => 'nats_address.example.com',
        'password' => 'nats-password',
        'user' => 'nats-user',
      },
    }
  end

  it 'is able to render the erb given most basic manifest properties' do
    expect(subject).to eq(
      'cloud' => {
        'plugin' => 'openstack',
        'properties' => {
          'agent' => {
            'blobstore' => {
              'options' => {
                'blobstore_path' => 'blobstore-local-path',
              },
              'provider' => 'local',
            },
            'mbus' => 'nats://nats-user:nats-password@nats_address.example.com:4222',
            'ntp' => [],
          },
          'openstack' => {
            'api_key' => 'openstack.api_key',
            'auth_url' => 'openstack.auth_url',
            'boot_from_volume' => false,
            'default_key_name' => 'openstack.default_key_name',
            'default_security_groups' => 'openstack.default_security_groups',
            'endpoint_type' => 'publicURL',
            'ignore_server_availability_zone' => 'openstack.ignore_server_availability_zone',
            'state_timeout' => 300,
            'stemcell_public_visibility' => false,
            'tenant' => 'openstack.tenant',
            'use_dhcp' => true,
            'username' => 'openstack.username',
            'wait_resource_poll_interval' => 'openstack.wait_resource_poll_interval',
            'human_readable_vm_names' => false,
            'use_nova_networking' => false,
            'default_volume_type' => nil,
          },
          'registry' => {
            'address' => 'registry.host',
            'endpoint' => 'http://registry.host:25777',
            'password' => 'registry.password',
            'user' => 'registry.username',
          },
        },
      },
    )
  end

  context 'when using an s3 blobstore' do
    let(:rendered_blobstore) { subject['cloud']['properties']['agent']['blobstore'] }

    context 'when provided a minimal configuration' do
      before do
        manifest['blobstore'].merge!(
          'provider' => 's3',
          'bucket_name' => 'my_bucket',
          'access_key_id' => 'blobstore-access-key-id',
          'secret_access_key' => 'blobstore-secret-access-key',
        )
      end

      it 'renders the s3 provider section with the correct defaults' do
        expect(rendered_blobstore).to eq(
          'provider' => 's3',
          'options' => {
            'bucket_name' => 'my_bucket',
            'access_key_id' => 'blobstore-access-key-id',
            'secret_access_key' => 'blobstore-secret-access-key',
            'use_ssl' => true,
            'ssl_verify_peer' => true,
            'port' => 443,
          },
        )
      end
    end

    context 'when provided a maximal configuration' do
      before do
        manifest['blobstore'].merge!(
          'provider' => 's3',
          'bucket_name' => 'my_bucket',
          'access_key_id' => 'blobstore-access-key-id',
          'secret_access_key' => 'blobstore-secret-access-key',
          's3_region' => 'blobstore-region',
          'use_ssl' => false,
          's3_port' => 21,
          'host' => 'blobstore-host',
          'ssl_verify_peer' => true,
          's3_signature_version' => '11',
        )
      end

      it 'renders the s3 provider section correctly' do
        expect(rendered_blobstore).to eq(
          'provider' => 's3',
          'options' => {
            'bucket_name' => 'my_bucket',
            'access_key_id' => 'blobstore-access-key-id',
            'secret_access_key' => 'blobstore-secret-access-key',
            'region' => 'blobstore-region',
            'use_ssl' => false,
            'host' => 'blobstore-host',
            'port' => 21,
            'ssl_verify_peer' => true,
            'signature_version' => '11',
          },
        )
      end

      it 'prefers the agent properties when they are both included' do
        manifest['agent'] = {
          'blobstore' => {
            'access_key_id' => 'agent_access_key_id',
            'secret_access_key' => 'agent_secret_access_key',
            's3_region' => 'agent-region',
            'use_ssl' => true,
            's3_port' => 42,
            'host' => 'agent-host',
            'ssl_verify_peer' => true,
            's3_signature_version' => '99',
          },
        }

        manifest['blobstore'].merge!(
          'access_key_id' => 'blobstore_access_key_id',
          'secret_access_key' => 'blobstore_secret_access_key',
          's3_region' => 'blobstore-region',
          'use_ssl' => false,
          's3_port' => 21,
          'host' => 'blobstore-host',
          'ssl_verify_peer' => false,
          's3_signature_version' => '11',
        )

        expect(rendered_blobstore['options']['access_key_id']).to eq('agent_access_key_id')
        expect(rendered_blobstore['options']['secret_access_key']).to eq('agent_secret_access_key')
        expect(rendered_blobstore['options']['region']).to eq('agent-region')
        expect(rendered_blobstore['options']['use_ssl']).to be true
        expect(rendered_blobstore['options']['port']).to eq(42)
        expect(rendered_blobstore['options']['host']).to eq('agent-host')
        expect(rendered_blobstore['options']['ssl_verify_peer']).to be true
        expect(rendered_blobstore['options']['signature_version']).to eq('99')
      end
    end
  end

  context 'when using human readable VM names' do
    it 'template render fails if registry endpoint is not set' do
      manifest['registry']['endpoint'] = nil
      manifest['openstack']['human_readable_vm_names'] = true

      expect { subject }.to raise_error RuntimeError,
                                        "Property 'human_readable_vm_names' can only be used together with" \
                                        " 'registry.endpoint'. Please refer to http://bosh.io/docs/openstack-registry.html."
    end

    it 'template render succeeds if registry endpoint is set' do
      manifest['registry']['endpoint'] = 'http://registry.host:25777'
      manifest['openstack']['human_readable_vm_names'] = true

      expect(subject['cloud']['properties']['registry']['endpoint']).to eq('http://registry.host:25777')
      expect(subject['cloud']['properties']['openstack']['human_readable_vm_names']).to be true
    end

    it 'template render succeeds if registry configured for bosh-init' do
      manifest['registry']['endpoint'] = nil
      manifest['registry']['host'] = '127.0.0.1'
      manifest['registry']['port'] = 6901
      manifest['openstack']['human_readable_vm_names'] = true

      expect(subject['cloud']['properties']['registry']['endpoint']).to eq('http://127.0.0.1:6901')
      expect(subject['cloud']['properties']['openstack']['human_readable_vm_names']).to be true
    end
  end

  describe 'when anti-affinity is configured' do
    [false, true].each do |prop|
      context "when anti-affinity is set to #{prop}" do
        it 'errors to inform the user this is no longer supported' do
          manifest['openstack']['enable_auto_anti_affinity'] = prop

          expect { subject }.to raise_error RuntimeError,
            "Property 'enable_auto_anti_affinity' is no longer supported. Please remove it from your configuration."
        end
      end
    end
  end
end