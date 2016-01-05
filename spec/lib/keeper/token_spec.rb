require 'spec_helper'

module Keeper
  RSpec.describe Token do
    let(:test_config) do
      {
        algorithm:        'HS256',
        secret:           'secret',
        expiry:           24.hours,
        issuer:           'api.example.com',
        audience:         'example.com',
        redis_connection: Redis.new(url: ENV['REDIS_URL'])
      }
    end
    let(:private_claims) { { claim: "Jet fuel can't melt steel beams" } }
    let(:raw_token)      { described_class.create(private_claims).to_jwt }

    before(:each) do
      Keeper.configure(Keeper::Configuration.new(test_config))
    end

    describe '#create' do
      subject { described_class.create(private_claims) }

      it { is_expected.to be_instance_of described_class }
      it { expect(subject.claims[:claim]).to eql private_claims[:claim] }
    end

    describe '#find' do
      subject { described_class.find(raw_token) }

      it { is_expected.to be_instance_of described_class }
      it { expect(subject.claims[:claim]).to eql private_claims[:claim] }

      context 'with invalid token' do
        let(:private_claims) { { exp: 1.hour.ago } }

        it { is_expected.to be nil }
      end

      context 'with revoked token' do
        before { described_class.find(raw_token).revoke }

        it { is_expected.to be nil }
      end
    end

    describe '.revoke' do
      subject(:token) { described_class.create(private_claims) }

      it 'invalidates the token' do
        expect(token.valid?).to eq true
        expect(token.revoked?).to eq false

        expect(token.revoke)

        expect(token.valid?).to eq false
        expect(token.revoked?).to eq true
      end
    end

    describe '#revoked?' do
      subject(:token) { described_class.create(private_claims) }

      context 'when token has been revoked' do
        before { token.revoke }

        it { is_expected.to be_revoked }
      end

      context 'when token is valid' do
        it { is_expected.not_to be_revoked }
      end
    end

    describe '#rotate' do
      let(:old_token) { described_class.create(private_claims) }
      let(:new_token) { old_token.dup.rotate }
      before { new_token }

      it { expect(old_token).to be_invalid }
      it { expect(new_token).to be_valid }
      it { expect(old_token.claims[:claim]).to eq new_token.claims[:claim] }
    end

    describe '.valid?' do
      subject { described_class.create(private_claims) }

      context 'when invalid' do
        before { Keeper.configure(Keeper::Configuration.new(test_config.merge(expiry: -1.hours))) }
        it { is_expected.not_to be_valid }
      end

      context 'when valid' do
        it { is_expected.to be_valid }
      end
    end

    describe '.invalid?' do
      subject { described_class.create(private_claims) }

      context 'when invalid' do
        before { Keeper.configure(Keeper::Configuration.new(test_config.merge(expiry: -1.hours))) }
        it { is_expected.to be_invalid }
      end

      context 'when valid' do
        it { is_expected.not_to be_invalid }
      end
    end
  end
end
