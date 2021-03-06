require 'spectator/emacs'

describe 'Spectator' do
  describe 'EmacsInteraction' do
    describe "Lisp sexp helpers" do
      describe "Symbol#keyword" do
        it "should be present" do
          :foobar.should respond_to(:keyword)
        end
        it "should add a ':' if the symbol name does not begin with ':'" do
          :foobar.keyword.should == :':foobar'
        end
        it "should not add a ':' if the symbol name already begins with ':'" do
          sym = :':foobar'
          sym.keyword.should == sym
        end
      end
      describe "Object#to_lisp" do
        it "should correctly represent a number" do
          20.times do
            num = rand(1..1000)
            num.to_lisp.should == "#{num}"
          end
        end

        it "should correctly represent a symbol" do
          symbol = :foobar
          symbol.to_lisp.should == "foobar"
        end

        it "should convert underscores to dashes when converting a symbol" do
          symbol = :foo_bar
          symbol.to_lisp.should == "foo-bar"
        end

        it "should correctly represent a string" do
          "asdf\nfoobar".to_lisp.should == '"asdf\nfoobar"'
        end

        it "should correctly represent an array as a list" do
          [1,2,3,4].to_lisp.should == '(1 2 3 4)'
          [1,2, [3, 4], 5, 6].to_lisp.should == '(1 2 (3 4) 5 6)'
          [:a, 1, :b, 2].to_lisp.should == '(a 1 b 2)'
        end

        describe "Hash#to_lisp" do
          before(:each) do
            @hash = {:a => [1,2,3], :b => 1, :c => "asdf"}
          end
          it "should correctly represent a hash as a plist" do
            @hash.as_plist.to_lisp.should == '(:a (1 2 3) :b 1 :c "asdf")'
          end
          it "should correctly represent a hash as an alist" do
            @hash.as_alist.to_lisp.should == '((a . (1 2 3)) (b . 1) (c . "asdf"))'
          end
          it "should correctly represent a hash as a flat list" do
            @hash.as_flat_list.to_lisp.should == '(a (1 2 3) b 1 c "asdf")'
          end
        end
      end
    end
  end
  describe "ERunner" do
    it "should inherit from Runner" do
      Spectator::ERunner.superclass.should be(Spectator::Runner)
    end
  end
end
