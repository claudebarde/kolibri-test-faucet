<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { TezosToolkit, ContractAbstraction, Wallet } from "@taquito/taquito";
  import { BeaconWallet } from "@taquito/beacon-wallet";
  import { NetworkType } from "@airgap/beacon-sdk";
  import { TezBridgeWallet } from "@taquito/tezbridge-wallet";

  const kolibriAddress = "KT1RXpLtz22YgX24QQhxKVyKvtKZFaAVtTB9";
  const ovenAddress = "KT1K4SGs8SNAtiZVJontHpCSiCtoLHj5ngLv";
  const contractAddress = "KT1MLPZy6ayaQwALYpGDfSDsWYQJLL8RjR68";
  const adminAddress = "tz1Me1MGhK7taay748h4gPnX2cXvbgL6xsYL";

  let Tezos: TezosToolkit;
  let contract: ContractAbstraction<Wallet>;
  let kolibriContract: ContractAbstraction<Wallet>;
  let wallet: BeaconWallet; // | TezBridgeWallet;
  let userAddress: string;
  let availableTokens: number | undefined = undefined;
  let approvedTokensToSpend: number | undefined = undefined;

  const initTezbridge = async () => {
    const newWallet = new TezBridgeWallet();
    Tezos.setWalletProvider(newWallet);
    userAddress = await newWallet.getPKH();
    wallet = newWallet;
  };

  const initBeacon = async () => {
    const newWallet = new BeaconWallet({
      name: "Beacon Test Dapp",
      eventHandlers: {
        ACTIVE_TRANSPORT_SET: {
          handler: async data => {
            console.log("active transport set:", data);
          }
        },
        ACTIVE_ACCOUNT_SET: {
          handler: async data => {
            console.log("active account set:", data);
          }
        },
        PAIR_SUCCESS: {
          handler: async data => {
            console.log("pair success:", data);
          }
        },
        PERMISSION_REQUEST_SENT: {
          handler: async data => {
            console.log("permission request success:", data);
          }
        },
        PERMISSION_REQUEST_SUCCESS: {
          handler: async data => {
            console.log("permission request success:", data);
          }
        },
        OPERATION_REQUEST_SENT: {
          handler: async data => {
            console.log("permission request success:", data);
          }
        },
        OPERATION_REQUEST_SUCCESS: {
          handler: async data => {
            console.log("permission request success:", data);
          }
        }
      }
    });
    await newWallet.requestPermissions({
      network: { type: NetworkType.DELPHINET }
    });
    Tezos.setWalletProvider(newWallet);
    userAddress = await newWallet.getPKH();
    wallet = newWallet;
  };

  const disconnectWallet = () => {
    if (wallet) {
      wallet.client.clearActiveAccount();
      wallet.client.destroy();
      wallet = undefined;
      userAddress = "";
    }
  };

  const transfer = async () => {
    try {
      const op = await contract.methods.transfer_request(userAddress).send();
      console.log(op.opHash);
      await op.confirmation();
    } catch (error) {
      console.log(error);
    }
  };

  onMount(async () => {
    Tezos = new TezosToolkit("https://testnet-tezos.giganode.io");
    contract = await Tezos.wallet.at(contractAddress);
    // fetches amount of tokens available
    kolibriContract = await Tezos.wallet.at(kolibriAddress);
    const storage: any = await kolibriContract.storage();
    const account = await storage.balances.get(adminAddress);
    if (account) {
      availableTokens = account.balance.toNumber() / 10 ** 18;
      approvedTokensToSpend =
        (await account.approvals.get(contractAddress)).toNumber() / 10 ** 18;
    }
  });

  onDestroy(() => disconnectWallet());
</script>

<style lang="scss">
  $green: #3eb48b;

  main {
    position: relative;
    height: 100%;
    display: grid;
    place-items: center;
  }

  .holder {
    position: relative;

    &:before,
    &:after {
      animation: orbit 10s linear infinite;
      border-radius: 50%;
      box-shadow: 0 0 1rem 0 rgba(0, 0, 0, 0.2);
      content: "";
      position: absolute;
    }

    &:before {
      background: $green;
      background: linear-gradient(
        20deg,
        rgba(62, 180, 139, 1) 0%,
        rgba(236, 248, 244, 1) 95%
      );
      height: 200px;
      width: 200px;
      top: 30px;
    }

    &:after {
      animation-delay: 5s;
      background: $green;
      background: linear-gradient(
        -20deg,
        rgba(62, 180, 139, 1) 0%,
        rgba(236, 248, 244, 1) 95%
      );
      right: 0px;
      top: 20px;
      z-index: -1;
      height: 150px;
      width: 150px;
    }
  }

  .card {
    border: 1px solid #fff;
    border-radius: 15px;
    box-shadow: 0 0 1rem 0 rgba(0, 0, 0, 0.2);
    font-size: 1rem;
    width: 500px;
    height: 300px;
    overflow: hidden;
    position: relative;

    &:before {
      background-color: rgba(255, 255, 255, 0.3);
      backdrop-filter: blur(10px) saturate(100%) contrast(45%) brightness(130%);
      content: "";
      height: 100%;
      position: absolute;
      width: 100%;
    }

    div.card__title {
      font-size: 2rem;
      margin-bottom: 20px;
    }

    div.card__content {
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      align-items: center;
      color: #6f7886;
      position: relative;
      z-index: 2;
      padding: 20px;
      text-align: center;
      height: 80%;
    }
  }

  .hummingbird {
    position: absolute;
    top: 10%;
    width: 100px;
  }

  button.button {
    background-color: $green;
    color: white;
    border-color: transparent;
    font-size: 1.5rem;
    cursor: pointer;
    border-radius: 4px;
    padding-bottom: calc(0.5em - 1px);
    padding-left: 1em;
    padding-right: 1em;
    padding-top: calc(0.5em - 1px);
    text-align: center;
    white-space: nowrap;
  }

  .disconnect {
    position: absolute;
    top: 20px;
    right: 20px;

    button {
      appearance: none;
      border: transparent;
      background-color: transparent;
      color: $green;
      font-size: 1.2rem;
      cursor: pointer;
    }
  }

  @keyframes orbit {
    from {
      transform: rotate(0deg) translateX(150px) rotate(0deg);
    }
    to {
      transform: rotate(360deg) translateX(150px) rotate(-360deg);
    }
  }
</style>

<main>
  <img
    src="hummingbird.svg"
    alt="hummingbird"
    class="hummingbird slide-in-elliptic-top-fwd"
  />
  {#if wallet && userAddress}
    <div class="disconnect">
      <button on:click={disconnectWallet}>Disconnect wallet</button>
    </div>
  {/if}
  <div class="holder">
    <div class="card">
      <div class="card__content">
        <div class="card__title">Kolibri Test Faucet</div>
        <div>
          Tokens available in oven: {availableTokens === undefined
            ? "---"
            : availableTokens} kUSD
        </div>
        <br />
        <div>
          Tokens available to spend: {approvedTokensToSpend === undefined
            ? "---"
            : approvedTokensToSpend} kUSD
        </div>
        <br />
        <div>
          {#if !wallet && !userAddress}
            <button class="button" on:click={initBeacon}
              >Connect your wallet</button
            >
          {:else}
            <button class="button" on:click={transfer}>Get 2 kUSD</button>
          {/if}
        </div>
      </div>
    </div>
  </div>
</main>
