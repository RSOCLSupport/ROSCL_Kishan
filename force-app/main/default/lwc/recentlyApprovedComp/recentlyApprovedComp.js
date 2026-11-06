import { LightningElement } from "lwc";
import getRecentlyApprovedReq from "@salesforce/apex/RSOCL_ApprovalProcessedDataController.getProcessedAprrovalRecords";
import { NavigationMixin } from "lightning/navigation";

export default class RecentlyApprovedComp extends NavigationMixin(
  LightningElement
) {
  sortedDirection;
  sortedColumn;
  data;
  recordIdStr;
  recordObjApiName;
  tableDataArray = [];
  _expendedObjectsMap = {};
  nameUpBool;
  nameDWBool;
  objUpBool;
  objDWBool;
  dateUpBool;
  dateDWBool;
  showSpinner = false;
  _currentApprovedStatus;
  showNoRecordsToDisplay = false;

  connectedCallback() {
    this.showSpinner = true;
    getRecentlyApprovedReq()
      .then((result) => {
        this.data = result;
        if (this.data && this.data?.length > 0) {
          this.data.forEach((row) => {
            const index = this.tableDataArray.findIndex(
              (x) => x.status === row.approvedStatus
            );
            if (index > -1) this.tableDataArray[index].childRecords.push(row);
            else
              this.tableDataArray.push({
                status: row.approvedStatus,
                rowColor: row.rowColor,
                childRecords: new Array(row)
              });
          });
          this.sortedColumn = "recordName";
          this.sortRecs();
        } else {
          this.showNoRecordsToDisplay = true;
        }
        this.showSpinner = false;
      })
      .catch(() => {
        this.data = undefined;
        this.showSpinner = false;
      });
  }

  handleChildRowDisplayAction(event) {
    this.showSpinner = true;
    const id = event.target.dataset.id;
    const displayProp = event.target.dataset.val;

    if (id) {
      this._expendedObjectsMap[id] = displayProp === "show" ? true : false;
    }
    this.showSpinner = false;
  }

  get getTableData() {
    const processedData = this.tableDataArray.map((row) => ({
      ...row,
      isExpended: this._expendedObjectsMap[row.status],
      totalChildRecordCount: row.childRecords?.length
    }));
    return processedData;
  }

  navigateToRecDetailsPage(event) {
    this.recordObjApiName = event.currentTarget.dataset.type;
    this.recordIdStr = event.currentTarget.dataset.val;
    this[NavigationMixin.GenerateUrl]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.recordIdStr,
        objectApiName: this.recordObjApiName,
        actionName: "view",
        tabName: "details"
      }
    }).then((generatedUrl) => {
      window.open(generatedUrl);
    });
  }

  sortRecs(event) {
    if (event) {
      this._currentApprovedStatus = event.target.dataset.type;
    }
    this.nameUpBool = false;
    this.nameDWBool = false;
    this.dateUpBool = false;
    this.dateDWBool = false;
    this.objUpBool = false;
    this.objDWBool = false;

    let colName = event ? event.target.name : undefined;
    if (this.sortedColumn === colName)
      this.sortedDirection = this.sortedDirection === "asc" ? "desc" : "asc";
    else this.sortedDirection = "asc";

    let isReverse = this.sortedDirection === "asc" ? 1 : -1;

    if (colName) this.sortedColumn = colName;
    else colName = this.sortedColumn;

    switch (colName) {
      case "recordName":
        if (this.sortedDirection === "asc") this.nameUpBool = true;
        else this.nameDWBool = true;

        break;

      case "relatedTo":
        if (this.sortedDirection === "asc") this.objUpBool = true;
        else this.objDWBool = true;

        break;

      case "approvedDate":
        if (this.sortedDirection === "asc") this.dateUpBool = true;
        else this.dateDWBool = true;

        break;

      default:
        break;
    }
    const data = [...this.tableDataArray];
    if (event) {
      data.forEach((row) => {
        if (row.status === this._currentApprovedStatus) {
          row.childRecords = JSON.parse(JSON.stringify(row.childRecords)).sort(
            (a, b) => {
              a = a[colName] ? a[colName].toLowerCase() : "z";
              b = b[colName] ? b[colName].toLowerCase() : "z";
              return a > b ? 1 * isReverse : -1 * isReverse;
            }
          );
        }
      });
    } else {
      data.forEach((row) => {
        row.childRecords = JSON.parse(JSON.stringify(row.childRecords)).sort(
          (a, b) => {
            a = a[colName] ? a[colName].toLowerCase() : "z";
            b = b[colName] ? b[colName].toLowerCase() : "z";
            return a > b ? 1 * isReverse : -1 * isReverse;
          }
        );
      });
    }
    this.tableDataArray = data;
  }
}
