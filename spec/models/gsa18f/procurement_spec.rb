describe Gsa18f::Procurement do
  it_behaves_like "client data"

  describe "Validations" do
    it { should validate_presence_of(:purchase_type) }
  end

  it "sets up initial approvers and observers" do
    DatabaseCleaner.clean_with(:truncation)
    Rails.application.load_seed
    procurement = create(:gsa18f_procurement, :with_steps)
    expect(procurement.approvers.map(&:email_address)).to eq(["gsa.approver+18f_approver@gmail.com"])
    expect(procurement.purchasers.map(&:email_address)).to eq(["gsa.approver+18f_purchaser@gmail.com"])
    expect(procurement.observers.map(&:email_address)).to be_empty
  end

  it "identifies eligible observers based on client_slug" do
    procurement = create(:gsa18f_procurement)
    user = create(:user, client_slug: 'gsa18f')
    expect(procurement.proposal.eligible_observers.to_a).to include(user)
    expect(procurement.proposal.eligible_observers.to_a).to_not include(procurement.observers)
  end

  describe "#purchase_type" do
    it "associates 0 with software" do
      procurement = build(:gsa18f_procurement, purchase_type: 0)

      expect(procurement.purchase_type).to eq "Software"
    end

    it "associates 2 with office supply or miscelleanous" do
      procurement = build(:gsa18f_procurement, purchase_type: 2)

      expect(procurement.purchase_type).to eq "Office Supply/Miscellaneous"
    end

    it "associates 3 with hardware" do
      procurement = build(:gsa18f_procurement, purchase_type: 3)

      expect(procurement.purchase_type).to eq "Hardware"
    end

    it "associates 4 with other" do
      procurement = build(:gsa18f_procurement, purchase_type: 4)

      expect(procurement.purchase_type).to eq "Other"
    end

    it "associates 5 with Micropurchase" do
      procurement = build(:gsa18f_procurement, purchase_type: 5)

      expect(procurement.purchase_type).to eq "Micropurchase"
    end
  end

  describe "#editable?" do
    it "is true" do
      procurement = build(:gsa18f_procurement)
      expect(procurement).to be_editable
    end
  end

  describe "#total_price" do
    it "gets price from two fields" do
      procurement = build(
        :gsa18f_procurement, cost_per_unit: 18.50, quantity: 20)
      expect(procurement.total_price).to eq(18.50 * 20)
    end
  end

  describe "#public_identifier" do
    it "returns proposal id prenended with pound" do
      procurement = build(:gsa18f_procurement)
      proposal = procurement.proposal

      expect(procurement.public_identifier).to eq "##{proposal.id}"
    end
  end

  describe " #purchaser_email" do
    let(:user) { double("user") }

    it "returns a micropurchase specific email" do
      allow(Gsa18f::Procurement).to receive(:user_with_role).with("gsa18f_micropurchase_purchaser").and_return(user)
      allow(user).to receive(:email_address) { "micropurchaser@somedotorg.org" }
      procurement = build(:gsa18f_procurement, purchase_type: 5)

      expect(Gsa18f::Procurement.purchaser_email "Micropurchase").to eq "micropurchaser@somedotorg.org"
    end

    it "returns a default email purchaser email" do
      allow(Gsa18f::Procurement).to receive(:user_with_role).with("gsa18f_purchaser").and_return(user)
      allow(user).to receive(:email_address) { "defaultpurchaser@somedotorg.org" }
      procurement = build(:gsa18f_procurement, purchase_type: 2)

      expect(Gsa18f::Procurement.purchaser_email "Software").to eq "defaultpurchaser@somedotorg.org"
    end
  end
end
