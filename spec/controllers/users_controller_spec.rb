require 'spec_helper'

describe UsersController do

  context "on GET to #edit" do
    let (:user) { Factory(:email_confirmed_user) }

    before do
      controller.stubs(:current_user => user)
      get :edit, :id => user.id
    end

    subject { controller }

    it { should assign_to(:user).with(user) }
    it { should render_template(:edit) }
  end

  context "on valid POST to #update" do
    let (:user) { Factory(:email_confirmed_user) }

    before do
      controller.stubs(:current_user => user)
      user.stubs(:update_attributes => true)
      post :update, :id => user.id
    end

    subject { controller }

    it { should assign_to(:user).with(user) }
    it { should set_the_flash.to(/success/) }
    it { should redirect_to(:root) }
  end

  context "on invalid POST to #update" do
   let (:user) { Factory(:email_confirmed_user) }

    before do
      controller.stubs(:current_user => user)
      user.stubs(:update_attributes => false)
      post :update, :id => user.id
    end

    subject { controller }

    it { should assign_to(:user).with(user) }
    it { should_not set_the_flash }
    it { should render_template(:edit) }

  end
end