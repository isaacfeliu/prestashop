require_relative 'test_helper'

module Prestashop
  module Mapper
    describe Image do
      let(:image) { Image.new(attributes_for(:image_basic)) }
      before do 
        Client.stubs(:id_language).returns(2)

        xml = <<-EOT
        <prestashop xmlns:xlink="http://www.w3.org/1999/xlink">
          <image_types>
            <image_type id="6" name="home_default" xlink:href="http://dev.demo.storio.cz/api/image_types/6"/>
            <image_type id="3" name="large_default" xlink:href="http://dev.demo.storio.cz/api/image_types/3"/>
            <image_type id="2" name="medium_default" xlink:href="http://dev.demo.storio.cz/api/image_types/2"/>
            <image_type id="1" name="small_default" xlink:href="http://dev.demo.storio.cz/api/image_types/1"/>
            <image_type id="4" name="thickbox_default" xlink:href="http://dev.demo.storio.cz/api/image_types/4"/>
          </image_types>
          <images>
            <image id="1" xlink:href="http://dev.demo.storio.cz/api/images/products/1"/>
          </images>
        </prestashop>
        EOT
      end

      it "must have valid images" do 
        image.images.must_be_kind_of Array
        image.images.must_equal([attributes_for(:image_basic)[:source]])
      end

      it "must upload all images" do 
        image.source = ['/image/first.png', '/image/second.png']
        image.expects(:uploader).with('/image/first.png').returns(10)
        image.expects(:uploader).with('/image/second.png').returns(13)
        image.upload.must_equal([10,13])
      end

      it "should perform upload" do
        WebMock.allow_net_connect!
        Client.expects(:upload)
        image.uploader('http://upload.wikimedia.org/wikipedia/en/b/bc/Wiki.png')
        image.file.expects(:format).never
      end

      it "should not take invalid url" do 
        image.uploader('/image/first.com').must_equal false
      end
    end 
  end
end
