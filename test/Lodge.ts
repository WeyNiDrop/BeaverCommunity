import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades,network } from "hardhat";

describe("Lodge", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployLodgeFixture() {
    
        const WoodERC20 = await ethers.getContractFactory("WoodERC20");
        const wood = await WoodERC20.deploy("Wood Coin", "WC");
        await wood.waitForDeployment();
        console.log("WoodERC20 deployed to:", await wood.getAddress());
      
        const BeaverERC721 = await ethers.getContractFactory("BeaverERC721");
        const beaver = await upgrades.deployProxy(BeaverERC721, ["Beaver", "Beaver"]);
        console.log("BeaverERC721 deployed to:", await beaver.getAddress());
      
        const Lodge = await ethers.getContractFactory("Lodge");
        const beaverAddress: string = await beaver.getAddress();
        const woodAddress: string = await wood.getAddress();
        const lodge = await upgrades.deployProxy(Lodge, [beaverAddress, woodAddress, 2]);
        console.log("Lodge deployed to:", await lodge.getAddress());
      
        const LODGE_ROLE = await beaver.LODGE_ROLE();
        await beaver.grantRole(LODGE_ROLE, lodge.getAddress());
      
        await wood.mint(lodge.getAddress());
    
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();
        
        return { wood, beaver, lodge, owner, otherAccount };
    }

    async function waitSecond(time: number): Promise<void> {
        // 使用 Promise 将 setTimeout 封装成异步操作
        return new Promise(resolve => {
          setTimeout(() => {
            resolve();
          }, time * 1000); // 1000 毫秒即 1 秒
        });
    }

    async function mint(){
        await network.provider.send("evm_mine", []);
    }

    describe("Deployment", function () {
        it("Should config correctly", async function () {
            const { wood, beaver, lodge, owner } = await loadFixture(deployLodgeFixture);
            expect(await lodge.currentRound()).to.equal(1);
            expect(await lodge.buildFee()).to.equal(0);
            expect(await lodge.buildFee()).to.equal(0);
            expect(await wood.balanceOf(owner)).to.equal(1e8);
            expect(await wood.balanceOf(lodge)).to.equal(9e8);

        });
    });

    describe("Functions", function(){
        it("Should output rewards value correctly", async function () {
            const { wood, beaver, lodge, owner } = await loadFixture(deployLodgeFixture);

            await network.provider.send("evm_setAutomine", [false]);
            await network.provider.send("evm_setIntervalMining", [0]);

            const lodgeAddress: string = await lodge.getAddress();
            await wood.approve(lodgeAddress, 1e9);
            await mint();
            await lodge.build(false, "hello, world");
            await mint();
            console.log("totalBeavers: ",await lodge.totalBeavers());
            await lodge.vote(1, 10);
            await mint();
            await waitSecond(2);
            console.log("competition: ",await lodge.competitionMapping(0));
            console.log("buildingRewards: ",await lodge.buildingRewards(1));
            console.log("sponsorRewards: ",await lodge.sponsorRewards(1, owner));
            await lodge.withdrawRoyalties(1);
            await mint();
            expect(await wood.balanceOf(owner)).to.equal(99999990 + 50000);
            const tx = await lodge.withdrawRewards(1);
            await mint();
            // verify events
            // await expect(tx).to.emit(wood, "Transfer").withArgs("to", owner);
            expect(await wood.balanceOf(owner)).to.equal(99999990 + 50000 + 940509);
        });
    });
});