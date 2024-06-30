const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

function getParsedJSON(tokenURI) {
  const base64Json = tokenURI.split("data:application/json;base64,")[1];
  const jsonString = Buffer.from(base64Json, 'base64').toString('utf-8');
  return JSON.parse(jsonString);
}

function getRawSVG(tokenURI) {
  const json = getParsedJSON(tokenURI);
  return json.image.split("data:image/svg+xml,")[1];
}

function getTokenAttributesDict(tokenURI) {
  const json = getParsedJSON(tokenURI);
  attributeDict = {};
  json.attributes.forEach(attr => {
    attributeDict[attr.trait_type] = attr.value;
  });
  return attributeDict;
}

describe("Osculate", function () {
  async function deployOsculateFixture() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const osculate = await ethers.deployContract("Osculate");

    return { osculate, owner, addr1, addr2, addr3 };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { osculate, owner } = await loadFixture(deployOsculateFixture);
      expect(await osculate.owner()).to.equal(owner.address);
    });

    it("Should mint the initial token to the owner", async function () {
      const { osculate, owner } = await loadFixture(deployOsculateFixture);
      expect(await osculate.ownerOf(0)).to.equal(owner.address);
    });

    it("Should have the correct initial supply", async function () {
      const { osculate } = await loadFixture(deployOsculateFixture);
      expect(await osculate.getSupply()).to.equal(1);
    });
  });

  describe("Minting", function () {
    it("Should allow users to mint tokens by paying 1 gwei", async function () {
      const { osculate, addr1 } = await loadFixture(deployOsculateFixture);
      await osculate.connect(addr1).mint({ value: ethers.parseUnits("1", "gwei") });
      expect(await osculate.ownerOf(1)).to.equal(addr1.address);
    });

    it("Should increase the total supply after minting", async function () {
      const { osculate, addr1 } = await loadFixture(deployOsculateFixture);
      await osculate.connect(addr1).mint({ value: ethers.parseUnits("1", "gwei") });
      expect(await osculate.getSupply()).to.equal(2);
    });

    it("Should revert if minting without sufficient funds", async function () {
      const { osculate, addr1 } = await loadFixture(deployOsculateFixture);
      await expect(
        osculate.connect(addr1).mint({ value: ethers.parseUnits("0", "gwei") })
      ).to.be.revertedWith("Insufficient funds to mint");
    });

    it("Should revert minting if the last minted token is owned by the same address", async function () {
      const { osculate, addr1 } = await loadFixture(deployOsculateFixture);
      await osculate.connect(addr1).mint({ value: ethers.parseUnits("1", "gwei") });
      await expect(
        osculate.connect(addr1).mint({ value: ethers.parseUnits("1", "gwei") })
      ).to.be.revertedWith("You can't kiss yourself!");
    });
  });

  describe("Token Properties", function () {
    it("Should return the correct token URI", async function () {
      const { osculate } = await loadFixture(deployOsculateFixture);
      const tokenURI = await osculate.tokenURI(0);
      console.log('Token URI:', tokenURI); 
      expect(tokenURI).to.include("data:application/json;base64,");
    });

    it("Should generate a valid SVG image", async function () {
      const { osculate } = await loadFixture(deployOsculateFixture);
      const tokenURI = await osculate.tokenURI(0);
      console.log('Token URI:', tokenURI);

      // Ensure the tokenURI is defined and contains the expected structure
      expect(tokenURI).to.not.be.undefined;
      expect(tokenURI).to.include("data:application/json;base64,");

      // Extract the SVG image
      const svgImage = getRawSVG(tokenURI);
      console.log('SVG Image:', svgImage);  // Log the SVG image for debugging

      // Check if the SVG image contains the expected SVG tags
      expect(svgImage).to.include("<svg");
    });

    it("Should generate correct attributes upon minting", async function () {
      const { osculate } = await loadFixture(deployOsculateFixture);
      const tokenURI = await osculate.tokenURI(0);

      const tokenAttr = getParsedJSON(tokenURI).attributes;
      /* const prevCipher = await osculate.getCipherOfPrevToken(0); */

      const expectedAttributes = [{"trait_type": "Previous Token Ciphertext", "value": "osculate"},{"trait_type": "Kissed", "value": "no"}];
      expect(tokenAttr).to.deep.equal(expectedAttributes);
  });

    it("Should change attributes if kissed", async function () {
      const { osculate, addr1 } = await loadFixture(deployOsculateFixture);
      await osculate.connect(addr1).mint({ value: ethers.parseUnits("1", "gwei") });
      const tokenURI_0 = await osculate.tokenURI(0);
      const tokenAttr = getTokenAttributesDict(tokenURI_0);

      expect(tokenAttr["Kissed"]).to.equal("yes");
    });

    it("Should generate correct svg upon minting", async function () {
      const { osculate } = await loadFixture(deployOsculateFixture);
      const tokenURI_0 = await osculate.tokenURI(0);

      const svgImage = getRawSVG(tokenURI_0);

      // Check if the animation duration is set to 1.5s
      const durMatch = svgImage.match(/dur='([^']*)'/);
      expect(durMatch[1]).to.equal('1.5');

      // Check if saturation is at 0
      const satMatch = svgImage.match(/stroke='hsl\(\d+,(0%25),\d+%25,\d\)'/);
      const saturation = satMatch[1].trim(); // Ensure no extra whitespace is included
      expect(saturation).to.equal('0%25');
    });

    it("Should change svg if kissed", async function () {
      const { osculate, addr1 } = await loadFixture(deployOsculateFixture);
      await osculate.connect(addr1).mint({ value: ethers.parseUnits("1", "gwei") });
      const tokenURI_0 = await osculate.tokenURI(0);

      const svgImage = getRawSVG(tokenURI_0);

      // Check if the animation duration changed to faster heartbeat dur='0.7'
      const durMatch = svgImage.match(/dur='([^']*)'/);
      expect(durMatch[1]).to.equal('0.7');

      // Check if saturation changed from 0 to 30%
      const satMatch = svgImage.match(/stroke='hsl\(\d+,(30%25),\d+%25,\d\)'/);
      const saturation = satMatch[1].trim(); // Ensure no extra whitespace is included
      expect(saturation).to.equal('30%25');
    });

    it("Should generate correct cipher upon minting", async function () {
      const { osculate, addr1, addr2, addr3 } = await loadFixture(deployOsculateFixture);
      await osculate.connect(addr1).mint({ value: ethers.parseUnits("1", "gwei") });
      await osculate.connect(addr2).mint({ value: ethers.parseUnits("1", "gwei") });

      const tokenURI_2_before = await osculate.tokenURI(2);
      console.log('Token URI 2 before:', tokenURI_2_before);

      await osculate.connect(addr3).mint({ value: ethers.parseUnits("1", "gwei") });
      const tokenURI_2 = await osculate.tokenURI(2);
      const tokenURI_3 = await osculate.tokenURI(3);

      console.log('Token URI 2 after:', tokenURI_2);

      const addr1Ciphertext = getTokenAttributesDict(tokenURI_2)["Previous Token Ciphertext"];
      const addr2Ciphertext = getTokenAttributesDict(tokenURI_3)["Previous Token Ciphertext"];

      const addr1CiphertextString = "fpfwi9vc";
      const addr2CiphertextString = "kp9oh2we";

      expect(addr1Ciphertext).to.equal(addr1CiphertextString);
      expect(addr2Ciphertext).to.equal(addr2CiphertextString);
    });
  });

});
