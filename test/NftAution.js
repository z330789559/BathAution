const NFTAuction = artifacts.require("./NFTAuction.sol");

const my1155Contract = artifacts.require("./My1155Contract.sol");
const Ethers = require('ethers');

const {
    expect
} = require('chai');

const {
    shouldFail,
    constants,
    balance,
    send,
    ether,
    expectEvent,
    expectRevert,
    BN,time
} = require('openzeppelin-test-helpers');

contract("NFTAuction", accounts => {

    const admintor = accounts[0]
    const bider = accounts[1]
    console.log(accounts[0],accounts[1],accounts[2],accounts[3],accounts[4])

    beforeEach(async function () {
        // Deploy a new Box contract for each test‘
        //console.log(accounts)
        //for (const a of accounts) {
        //    let balance = await web3.eth.getBalance(a);
        //    console.log("account:",a,": ",web3.utils.fromWei(balance,"ether"));
        //}

        this.aution = await NFTAuction.deployed();
        this.erc1155 = await my1155Contract.deployed();

        // console.log(erc1155Address);
        // this.aution= await NFTAuction.at(autionAddress);
        // this.erc1155= await my1155Contract.at(erc1155Address);
    
    });

    it("approve 1155 should success.", async function () {

        console.log(this.aution.address)
        console.log(this.erc1155.address)
        await this.erc1155.mint(bider, 1,3, []);
        const balance = await this.erc1155.balanceOf(bider, 1);
        expect(balance.toString()).to.equal("3")
        console.log("admin", admintor, bider)
        const result = await this.erc1155.setApprovalForAll(this.aution.address, true, {
            from: bider
        });
        expectEvent(result, "ApprovalForAll", {
            account: bider,
            operator: this.aution.address,
            approved: true
        })

        const event = await this.aution.publishAution(this.erc1155.address, 1, Ethers.utils.parseEther("1"), 2, "http://ipfs.zifu.vip/ipns/k51qzi5uqu5djhwoxgbo67x0iox7ts6b4mu0lixbu1oz1fxsm0e4bt8i45jazn/GameLootBox/1.png", {
            from: bider,
            value: Ethers.utils.parseEther("2")
        });


        expectEvent(event, "PublishSuccess", {
            contractAddresss: this.erc1155.address,
            from: bider,
            to: this.aution.address,
            tokenid: new BN('1'),
            amount: new BN('2')
        })
    });


    it("bid NFT  should success", async function () {
        let bidIds = await this.aution.getActions();

        console.log("bidIds", bidIds);
        let bidId = await this.aution.userAution(bider);
        console.log("bidId", bidId);

           let result1=  await this.aution.bid(bidId,{from: accounts[2],value:  Ethers.utils.parseEther("1")})

           expectEvent(result1,"Bid",{
            bidAddress: bidId,
            price: new BN("1000000000000000000"),
            bider: accounts[2],
            count: new BN("1"),
           })
  
            let result2= await this.aution.bid(bidId,{from: accounts[3],value:  Ethers.utils.parseEther("1")})
     

            expectEvent(result2,"Bid",{
                bidAddress: bidId,
                price: new BN("1000000000000000000"),
                bider: accounts[3],
                count:new BN("2"),
            })
            let applyNumber= await this.aution.getAutionApplyNumber(bidId);
            expect(applyNumber.toString()).to.equal("2")
          
       
    })


    it("bid NFT  should fail", async function () {
        let bidId = await this.aution.userAution(bider);
      
        // let result1=  await this.aution.bid(bidId,{from: accounts[2],value:  Ethers.utils.parseEther("0.5")})
        // console.log(result1)
       await  expectRevert(this.aution.bid(bidId,{from: accounts[2],value:  Ethers.utils.parseEther("0.5")}),"n2")

        let result2=  await this.aution.bid(bidId,{from: accounts[4],value:  Ethers.utils.parseEther("1.2")})
        expectEvent(result2,"Bid",{
         bidAddress: bidId,
         price: new BN("1200000000000000000"),
         bider: accounts[4],
         count:new BN("2")
        })
        let  minPrice= await this.aution.getMinPrice(bidId);
        console.log("minPrice",minPrice[0].toString(),minPrice[1].toString(),minPrice[2].toString())
    })



    it("overbid NFT  should success", async function () {
        await time.increase(86401); // 1 hour 2 minutes
        let bidId = await this.aution.userAution(bider);

        await  expectRevert(this.aution.overAution(bider),"n1")

        let result = await this.aution.overAution(bidId);
         expectEvent(result,"Over",{
        bidAddress: bidId,
        status:"2"
      })

    })


    it("autionConfirm  should success", async function () {

       let  amount =await balance.current(admintor);
       console.log(amount.toString())

       let  amountBider =await balance.current(bider);
       console.log(amountBider.toString())
        let bidId = await this.aution.userAution(bider);

         let result = await this.aution.autionConfirm(bidId,{from: bider});
         let bidIds = await this.aution.getActions();
           console.log(bidIds)
          expectEvent(result,"Settle",{
            bidAddress: bidId,
            contractAddresss: this.erc1155.address,
            tokenId: new BN("1"),
            minPrice: new BN("1000000000000000000")
          })
           await this.aution.setBiders(bidId);
          let bidIds2 = await this.aution.getBiders();

          console.log("autions 为 ",bidIds2);


          const refund4= await this.aution.refunds(accounts[4]);
          console.log("refund4 ",refund4.toString());
           expect(refund4.toString()).to.equal("200000000000000000");

           const refund1= await this.aution.refunds(bider);

           expect(refund1.toString()).to.equal(1000000000000000000 * 4 +"")
           const nftBalance = await this.erc1155.balanceOf(bider, 1);
           expect(nftBalance.toString()).to.equal("1")

           const nftBalance1 = await this.erc1155.balanceOf(accounts[4], 1);
           expect(nftBalance1.toString()).to.equal("1")

           const nftBalance2 = await this.erc1155.balanceOf(accounts[3], 1);
           expect(nftBalance2.toString()).to.equal("1")
  

    })


});