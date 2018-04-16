# -*- coding: utf-8 -*-
# Copyright: Copyright (c) 2018 Chef Software, Inc.
# License: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "pedant/rspec/cookbook_util"

describe "Cookbooks API endpoint", :cookbooks, :cookbooks_conversion do
  let(:cookbook_url_base) { "cookbooks" }

  before do
    platform.reset_server_api_version
  end

  after do
    platform.reset_server_api_version
  end

  include Pedant::RSpec::CookbookUtil

  context "requests with different API versions" do
    include Pedant::RSpec::Validations::Create

    let(:sandbox) { create_sandbox(files) }
    let(:upload) { ->(file) { upload_to_sandbox(file, sandbox) } }
    let(:files) { (0..3).to_a.map { Pedant::Utility.new_random_file } }

    let(:committed_files) do
      files.each(&upload)
      result = commit_sandbox(sandbox)
      result
    end

    let(:checksums) { parse(committed_files)["checksums"] }

    let(:request_method) { :PUT }
    shared(:requestor) { admin_user }
    let(:request_url) { api_url("/#{cookbook_url_base}/#{cookbook_name}/#{cookbook_version}") }
    let(:cookbook_name) { "cookbook_name" }
    let(:cookbook_version) { self.class.cookbook_version }
    let(:recipes) do
      [{
        "name" => "default.rb",
        "path" => "recipes/default.rb",
        "checksum" => checksums[0],
        "specificity" => "default"
      }]
    end

    after do
      delete_cookbook(admin_user, cookbook_name, cookbook_version)
    end

    # TODO: KLUDGE: Cop-out, because I am too tired to refactor the macros correctly
    def self.cookbook_version
      "1.2.3"
    end

    it "uploads as v0, downloads as v2" do
      platform.server_api_version = 0
      payload = new_cookbook(cookbook_name, cookbook_version, recipes: recipes)
      put(request_url, admin_user, payload: payload) do |response|
        response.should look_like({
          status: 201,
          body: payload,
        })
      end

      platform.server_api_version = 2
      expected_payload = new_cookbook(cookbook_name, cookbook_version, recipes: recipes)
      get(request_url, admin_user) do |response|
        response.should look_like({
          status: 200,
          body: expected_payload,
        })
      end
    end

    it "uploads as v2, downloads as v0" do
      platform.server_api_version = 2
      payload = new_cookbook(cookbook_name, cookbook_version, recipes: recipes)
      put(request_url, admin_user, payload: payload) do |response|
        response.should look_like({
          status: 201,
          body: payload,
        })
      end

      platform.server_api_version = 0
      expected_payload = new_cookbook(cookbook_name, cookbook_version, recipes: recipes)
      get(request_url, admin_user) do |response|
        response.should look_like({
          status: 200,
          body: expected_payload,
        })
      end
    end
  end
end