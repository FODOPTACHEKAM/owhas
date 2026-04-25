const PDFDocument = require('pdfkit');

const generateAttendancePDF = (dataList, stream) => {
    // 1. Initialize Document
    const doc = new PDFDocument({ 
        margin: 50, 
        size: 'A4',
        info: { Title: 'Attendance Report', Author: 'Hotspot System' } 
    });
    
    doc.pipe(stream);

    // 2. Add Header
    doc.fontSize(20).fillColor('#0f2c3b').text('ATTENDANCE REPORT', { align: 'center' });
    doc.fontSize(10).fillColor('black').text(`Generated on: ${new Date().toLocaleString()}`, { align: 'center' });
    doc.moveDown(2);

    // 3. Table Header
    const startX = 50;
    let currentY = doc.y;
    const colWidths = { name: 150, matricule: 100, email: 180, time: 80 };

    doc.fontSize(12).font('Helvetica-Bold');
    doc.text('Name', startX, currentY);
    doc.text('Matricule', startX + colWidths.name, currentY);
    doc.text('Email', startX + colWidths.name + colWidths.matricule, currentY);
    doc.text('Time', startX + colWidths.name + colWidths.matricule + colWidths.email, currentY);
    
    doc.moveTo(startX, currentY + 15).lineTo(550, currentY + 15).stroke();
    currentY += 25;

    // 4. Data Rows
    doc.font('Helvetica').fontSize(10);
    
    dataList.forEach((user) => {
        // Check for page overflow
        if (currentY > 750) {
            doc.addPage();
            currentY = 50; 
        }

        // Use 'username' to match your server.js logic
        doc.text(user.username || 'N/A', startX, currentY);
        doc.text(user.matricule || 'N/A', startX + colWidths.name, currentY);
        doc.text(user.email || 'N/A', startX + colWidths.name + colWidths.matricule, currentY);
        doc.text(user.time || '--:--', startX + colWidths.name + colWidths.matricule + colWidths.email, currentY);
        
        currentY += 20;
    });

    // 5. Finalize
    doc.end();
};

module.exports = { generateAttendancePDF };