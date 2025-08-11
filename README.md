# 🌱 Community-Owned Renewable Energy Grid

A decentralized platform for tokenizing ownership in renewable energy sources, enabling communities to collectively own and profit from clean energy infrastructure.

## 🚀 Features

- 🏗️ **Create Energy Grids**: Deploy renewable energy projects (solar farms, wind farms, etc.)
- 💰 **Tokenized Ownership**: Purchase shares in energy projects using STX
- 📈 **Earnings Distribution**: Automatically distribute profits from energy sales to shareholders
- 🔄 **Share Trading**: Transfer ownership shares between users
- 🎯 **Transparent Tracking**: Real-time visibility of earnings and ownership

## 🛠️ How It Works

### For Grid Owners
1. **Deploy a Grid**: Create a new renewable energy project with defined capacity and share structure
2. **Set Share Price**: Define the cost per ownership share
3. **Add Earnings**: Regularly distribute profits from energy sales to shareholders

### For Investors
1. **Browse Grids**: Explore available renewable energy projects
2. **Purchase Shares**: Buy ownership stakes using STX tokens
3. **Earn Rewards**: Receive proportional earnings from energy sales
4. **Trade Shares**: Transfer ownership to other users

## 📋 Contract Functions

### Public Functions

#### `create-energy-grid`
Create a new renewable energy grid project
```clarity
(create-energy-grid "Solar Farm Alpha" "California, USA" u5000 u1000 u100)
```

#### `purchase-shares`
Buy ownership shares in an energy grid
```clarity
(purchase-shares u1 u50)
```

#### `add-energy-earnings`
Add earnings from energy sales (grid owner only)
```clarity
(add-energy-earnings u1 u10000)
```

#### `claim-earnings`
Claim accumulated earnings from owned shares
```clarity
(claim-earnings u1)
```

#### `transfer-shares`
Transfer shares to another user
```clarity
(transfer-shares u1 u25 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Read-Only Functions

#### `get-grid-info`
Get detailed information about an energy grid
```clarity
(get-grid-info u1)
```

#### `get-pending-earnings`
Check unclaimed earnings for a user
```clarity
(get-pending-earnings 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)
```

## 🎮 Usage Example

```bash
clarinet console
```

```clarity
;; Create a solar farm
(contract-call? .Community-Owned create-energy-grid "Solar Farm Beta" "Texas, USA" u3000 u500 u200)

;; Purchase 10 shares
(contract-call? .Community-Owned purchase-shares u1 u10)

;; Add earnings (as grid owner)
(contract-call? .Community-Owned add-energy-earnings u1 u5000)

;; Claim your earnings
(contract-call? .Community-Owned claim-earnings u1)
```

## 🔧 Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks CLI](https://docs.stacks.co/docs/command-line-interface)

### Setup
```bash
clarinet new community-energy-grid
cd community-energy-grid
```

### Testing
```bash
clarinet test
```

### Deploy
```bash
clarinet deploy --testnet
```

## 🌍 Environmental Impact

This platform democratizes access to renewable energy investments, enabling:
- 🌿 **Community Ownership** of clean energy infrastructure
- 💚 **Sustainable Returns** from environmentally friendly projects  
- 🤝 **Collective Action** towards carbon neutrality
- 📊 **Transparent Impact** tracking and reporting

## 🔐 Security Features

- ✅ Owner-only functions for grid management
- ✅ Balance validation for all transactions
- ✅ Share transfer restrictions and validations
- ✅ Earnings calculation protection against overflow

## 📈 Token Economics
