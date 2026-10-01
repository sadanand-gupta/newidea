// Watchlist coin ids persisted to a JSON file.
const fs = require('node:fs');

class WatchlistStore {
  constructor(filePath) {
    this.filePath = filePath;
  }

  ids() {
    try {
      const ids = JSON.parse(fs.readFileSync(this.filePath, 'utf8'));
      return Array.isArray(ids) ? ids.filter((x) => typeof x === 'string') : [];
    } catch {
      return [];
    }
  }

  add(id) {
    const ids = this.ids();
    if (!ids.includes(id)) {
      ids.push(id);
      this.#save(ids);
    }
    return ids;
  }

  remove(id) {
    const ids = this.ids().filter((x) => x !== id);
    this.#save(ids);
    return ids;
  }

  #save(ids) {
    fs.writeFileSync(this.filePath, JSON.stringify(ids));
  }
}

module.exports = { WatchlistStore };
